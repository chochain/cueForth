/**
 * @file
 * @brief AIO class - asyn IO module implementation
 * @note
 *    AIO takes managed memory blocks as input and output buffers
 *    which can be access by both device and host
 *
 * <pre>Copyright (C) 2021 GreenII, this file is distributed under BSD 3-Clause License.</pre>
 *
 */
#ifndef TEN4_SRC_AIO_H
#define TEN4_SRC_AIO_H
#include "istream.h"
#include "ostream.h"
#include "t4base.h"
#include "tensor.h"
#include "dataset.h"                  // in ../mmu
#include "model.h"                    // in ../mmu
#include "ldr/loader.h"               // in ../ldr (include corpus.h)

typedef std::istream h_istr;          ///< host input stream
typedef std::ostream h_ostr;          ///< host output ostream

#define IO_TRACE(...)      { if (trace) INFO(__VA_ARGS__); }

class AIO {                           ///< create in host mode
public:
    friend class Debug;               ///< Debug can access my private members
    
    h_istr &fin;                      ///< host input stream
    h_ostr &fout;                     ///< host output stream
    int    trace;                     ///< debug tracing verbosity level
    
#if DO_MULTITASK
    static bool     io_busy;          ///< IO locking control
    static MUTEX    io;               ///< mutex for io access
    static COND_VAR cv_io;            ///< io control
    ///
    /// IO interface
    ///
    static void io_lock();            ///< lock IO
    static void io_unlock();          ///< unlock IO
#endif // DO_MULTITASK
    
    AIO(h_istr &i, h_ostr &o, int verbo) : fin(i), fout(o), trace(verbo) {}

    __HOST__ void show(DU v, int rdx=10); ///< display value by ss_dump
    __HOST__ void print(DU v);            ///< print object info to fout

private:
    int     _radix = 10;              ///< output stream radix
    int     _thres = 10;              ///< max cell count for each dimension
    int     _edge  = 3;               ///< number of tensor edge items
    int     _prec  = 4;               ///< shown floating point precision

#if T4_ENABLE_OBJ // vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
    ///
    /// Tensor print methods
    ///
    __HOST__ void _show_obj(T4Base &t, bool view);  ///< display object on ss_dump
    __HOST__ void _print_vec(DU *vd, U32 W, U32 C);
    __HOST__ void _print_mat(DU *md, U32 *shape);
    __HOST__ void _print_tensor(Tensor &t);
    ///
    /// Tensor persistence (i.e. serialization) methods
    ///
    __HOST__ int  _tsave(DU top, U8 mode, char *fname);
    __HOST__ int  _tsave_txt(Tensor &t);
    __HOST__ int  _tsave_raw(Tensor &t);
    __HOST__ int  _tsave_npy(Tensor &t);
    
#if T4_ENABLE_NN
    ///
    /// NN model print methods
    ///
    __HOST__ void _print_model(Model &m);
    __HOST__ void _print_model_parm(Tensor &in, Tensor &out);
    ///
    /// dataset IO methods
    ///
    __HOST__ int  _dsfetch(Dataset &ds, char *ds_name=NULL, bool rewind=0); ///< fetch a dataset batch (rewind=false load batch)
    ///
    /// NN model persistence (i.e. serialization) methods
    ///
    __HOST__ int  _nsave(Model &m, char *fname, U8 mode);
    __HOST__ int  _nload(Model &m, char *fname, U8 mode);
    
    __HOST__ int  _nsave_model(Model &m);
    __HOST__ int  _nsave_param(Model &m);
    __HOST__ int  _nload_model(Model &m, char *fname);
    __HOST__ int  _nload_param(Model &m);

#endif // T4_ENABLE_NN
#endif // T4_ENABLE_OBJ ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
};

#endif // TEN4_SRC_AIO_H
