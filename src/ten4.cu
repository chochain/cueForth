/** -*- c++ -*-
 * @file - ten4.cu
 * @brief - tensorForth value definitions non-optimized
 *
 * <pre>Copyright (C) 2022- GreenII, this file is distributed under BSD 3-Clause License.</pre>
 *
 * Benchmark: 1K*1K cycles on 3.2GHz AMD, Nvidia GTX1660
 *    + 19.0 sec - REALLY SLOW! Probably due to heavy branch divergence.
 *    + 21.1 sec - without NXT cache in nest() => branch is slow
 *    + 19.1 sec - without push/pop WP         => static ram access is fast
 *    + 20.3 sec - token indirect threading    => not that much worse but portable
 */
#include <iostream>          // cin, cout
#include <signal.h>

using namespace std;
#include "netvm.h"           // VM + ForthVM + TensorVM + NetVM
#include "ten4.h"            // wrapper

#define MAJOR_VERSION        "3"
#define MINOR_VERSION        "0"

__GPU__ NetVM *vm_pool[VM_MIN_COUNT]; /// TODO: CC - polymorphic does not work?
///
/// instantiate VMs (threadIdx.x is vm_id)
///
__KERN__ void
k_ten4_init(int khz, Istream *istr, Ostream *ostr, MMU *mmu) {
    auto  g   = cg::this_thread_block();
    int   vid = g.thread_rank();      ///< VM id
    
    NetVM *vm;
    if (vid < VM_MIN_COUNT) {
        vm = vm_pool[vid] = new NetVM(khz, istr, ostr, mmu);  /// * instantiate VM
        vm->ss.init(mmu->vmss(vid), T4_SS_SZ);  /// * point data stack to managed memory block
        vm->status = VM_WAIT;                   /// * workers wait in queue
        
        if (vid==0) {
            vm->init();                         /// * initialize common dictionary (once only)
            mmu->status();                      /// * report MMU status after init
            vm->status = VM_READY;              /// * VM[0] available for work
        }
    }
    g.sync();
}
///
/// check VM status (using warp-level collectives)
///
__KERN__ void
k_ten4_busy(int *busy) {
    int vid = threadIdx.x;                 ///< VM id
    if (vid < VM_MIN_COUNT) {
        if (vm_pool[vid]->status != VM_STOP) {
            auto g1 = cg::coalesced_threads();
            if (vid == 0) *busy = g1.size();
        }
    }
}
///
/// tensorForth kernel - VM dispatcher
/// Note: 1 block per VM, thread 0 working only (wasteful?)
///
__KERN__ void
k_ten4_exec(int trace) {
    const char *st[] = {"READY", "RUN", "WAIT", "STOP"};
    extern __shared__ DU shared_ss[];           ///< use shard mem for ss

    const int tx  = threadIdx.x;                ///< thread id (0 only)
    const int vid = blockIdx.x;                 ///< VM id

    VM *vm = vm_pool[vid];
    if (tx == 0 && vm->status != VM_STOP) {     /// * one thread per VM
        DU *ss  = &shared_ss[vid * T4_SS_SZ];   ///< each VM uses its own ss
        DU *ss0 = vm->ss.v;                     ///< VM's data stack

        MEMCPY(ss, ss0, sizeof(DU) * T4_SS_SZ); /// * copy stack into shared memory block
        vm->ss.v = ss;                          /// * redirect data stack to shared memory
        
        vm->outer();                            /// * enter VM outer loop
        
        MEMCPY(ss0, ss, sizeof(DU) * T4_SS_SZ); /// * copy updated stack back to global mem
        vm->ss.v = ss0;                         /// * restore stack ptr
    }
    if (trace > 0) INFO("VM[%d].%d.%s\n", vid, tx, st[vm->status]);
}
///
/// clean up marked free tensors
///
__KERN__ void
k_ten4_sweep(MMU *mmu) {
    auto g = cg::this_thread_block();
//    mmu->lock();
    if (blockIdx.x == 0 && g.thread_rank() == 0) {
        mmu->sweep();
    }
    g.sync();
//    mmu->unlock(); !!! DEAD LOCK now
}

TensorForth::TensorForth(int device, int verbose) {
    ///
    /// set active device
    ///
    cudaError_t err = cudaSetDevice(device);
    if (err != cudaSuccess) {
        cerr << "\nERR: failed to activate GPU " << device << "\n";
        exit(1);
    }
    ///
    /// query GPU shader clock rate
    ///
    int khz = 0;
    cudaDeviceGetAttribute(&khz, cudaDevAttrClockRate, device);
    GPU_CHK();

    cout << "\\  GPU " << device
         << " initialized at " << khz/1000 << "MHz"
         << ", dict["          << T4_DICT_SZ << "]"
         << ", vmss["          << T4_SS_SZ << "*" << VM_MIN_COUNT << "]"
         << ", pmem="          << T4_PMEM_SZ/1024 << "K"
         << ", tensor="        << T4_TENSOR_SZ/1024/1024 << "M"
         << endl;
    ///
    /// allocate cuda memory blocks
    ///
    mmu = new MMU(verbose);                     ///> instantiate memory manager
    aio = new AIO(mmu, verbose);                ///> instantiate async IO manager
    cudaMalloc((void**)&busy, sizeof(int));     ///> allocate managed busy flag
    GPU_CHK();
    ///
    /// instantiate virtual machines
    ///
    int t = WARP(VM_MIN_COUNT);                 ///> thread count = 32 modulo
    k_ten4_init<<<1, t>>>(khz, aio->istream(), aio->ostream(), mmu); // create VMs
    GPU_CHK();
}

TensorForth::~TensorForth() {
    delete aio;
    cudaFree(busy);
    cudaDeviceReset();
}

__HOST__ int
TensorForth::is_ready() {
    int h_busy = 0;
    //LOCK();                 // TODO: lock on vm_pool
    int t = WARP(VM_MIN_COUNT);
    k_ten4_busy<<<1, t>>>(busy);
    GPU_SYNC();
    //UNLOCK();               // TODO:
    cudaMemcpy(&h_busy, busy, sizeof(int), D2H);
    return h_busy;
}

#define VMSS_SZ (sizeof(DU) * T4_SS_SZ * VM_MIN_COUNT)
__HOST__ int
TensorForth::run() {          /// TODO: check ~CUDA/samples/simpleCallback for multi-workload callback
    int trace = mmu->trace();
    while (is_ready()) {
        if (aio->readline()) {        // feed from host console to managed input buffer
            k_ten4_exec<<<VM_MIN_COUNT, 1, VMSS_SZ>>>(trace);
            GPU_CHK();                // cudaDeviceSynchronize() and check error
            aio->flush();             // flush output buffer
            k_ten4_sweep<<<1, 1>>>(mmu);
            cudaDeviceSynchronize();
        }
        yield();
        
#if T4_MMU_DEBUG
        int m0 = (int)mmu->here() - 0x80;
        mmu->mem_dump(cout, m0 < 0 ? 0 : m0, 0x80);
#endif // T4_MMU_DEBUG
        break;
    }
    return 0;
}

__HOST__ void
TensorForth::teardown(int sig) {}
///
/// main program
///
void sigsegv_handler(int sig, siginfo_t *si, void *arg) {
    cout << "Exception caught at: " << si->si_addr << endl;
    exit(1);
}

void sigtrap() {
    struct sigaction sa;
    memset(&sa, 0, sizeof(struct sigaction));
    sigemptyset(&sa.sa_mask);
    sa.sa_sigaction = sigsegv_handler;
    sa.sa_flags     = SA_SIGINFO;
    sigaction(SIGSEGV, &sa, NULL);
}

#include "opt.h"
int main(int argc, char**argv) {
    sigtrap();
    
    const string APP = string(T4_APP_NAME) + " " + MAJOR_VERSION + "." + MINOR_VERSION;
    Options opt;
    opt.parse(argc, argv);
    
    if (opt.help) {
        opt.print_usage(std::cout);
        opt.check_devices(std::cout);
        cout << "\nRecommended GPU: " << opt.device_id << std::endl;
        return 0;
    }
    else opt.check_devices(std::cout, false);

    cout << APP << endl;
    
    TensorForth *f = new TensorForth(opt.device_id, opt.verbose);
    f->run();

    cout << APP << " done." << endl;
    f->teardown();

    return 0;
}


    
