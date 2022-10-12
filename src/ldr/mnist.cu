/** -*- c++ -*-
 * @file
 * @brief Mnist class - MNIST dataset provider host implemenation
 *
 * <pre>Copyright (C) 2022- GreenII, this file is distributed under BSD 3-Clause License.</pre>
 */
#include "mnist.h"

#define LOG_COUNT 1024
#define LOG_MAX   300

Corpus *Mnist::fetch(int batch_id, int batch_sz) {
    static int bound = LOG_COUNT / batch_sz, tick = 0;
    
    if (N == 0 && _setup()) return NULL;           /// * setup once only
    eof = 0;
    
    int bsz = batch_sz ? batch_sz : N;             ///< batch size
    int b0  = _get_labels(batch_id, bsz);          ///< load batch labels
    int b1  = _get_images(batch_id, bsz);          ///< load batch images
    if (b0 != b1) {
        DS_ERROR("ERROR: Mnist::fetch #label=%d != #image=%d\n", b0, b1);
        return NULL;
    }
    if ((tick % bound) == 0) {
        DS_LOG1("\n\tMnist batch[%d] loaded (size=%d)\n", batch_id, b0);
        _preview(bsz < 3 ? bsz : 3);               /// * debug print
    }
    if ((++tick * batch_sz) > LOG_MAX) eof = 1;
    return this;
}

int Mnist::_open() {
    if (ds_name) {
        d_in.open(ds_name, std::ios::binary);
        if (!d_in.is_open()) { IO_ERROR(ds_name); return -1; }
    }
    if (tg_name) {
        t_in.open(tg_name, std::ios::binary);
        if (!t_in.is_open()) { IO_ERROR(tg_name); return -1; }
    }
    return 0;
}

int Mnist::_close() {
    if (d_in.is_open()) d_in.close();
    if (t_in.is_open()) t_in.close();
    return 0;
}

int Mnist::_setup() {
    auto _u32 = [this](std::ifstream &fs) {
        U32 v = 0;
        char x;
        for (int i = 0; i < 4; i++) {
            fs.read(&x, 1);
            v <<= 8;
            v += (U32)*(U8*)&x;
        }
        return v;
    };
    if (_open()) return -1;
    
    U32 X0, X1, N1=0;
    if (t_in) {
        X1 = _u32(t_in);    ///< label magic number 0x0801
        N1 = _u32(t_in);
        DS_LOG1("\n\tMNIST label: magic=%08x => [%d]", X1, N1);
    }
    if (d_in) {
        X0 = _u32(d_in);    ///< image magic number 0x0803
        N  = _u32(d_in);
        H  = _u32(d_in);
        W  = _u32(d_in);
        C  = 1;
        DS_LOG1("\n\tMNIST image: magic=%08x => [%d][%d,%d,%d]",
               X0, N, H, W, C);
    }
    if (N != N1) {
        DS_ERROR("ERROR: Mnist label count %d != image count %d\n", N1, N);
        return -2;
    }
    return 0;
}

int Mnist::_preview(int N) {
    static const char *map = " .:-=+*#%@";

    for (int i = 0; i < H; i++) {
        for (int n =0; n < N; n++) {
            U8 *img = (*this)[n] + i * W;
            for (int j = 0; j < W; j++, img++) {
                char c  = map[*img / 26];
                char c1 = map[((int)*img + (int)*(img+1)) / 52];
                DS_LOG1("%c%c", c, c1);                 // double width
            }
            DS_LOG1("|");
        }
        DS_LOG1("\n");
    }
    for (int n = 0; n < N; n++) {
        DS_LOG1(" label=%-2d ", (int)label[n]);
        for (int j = 0; j < W*2 - 10; j++) DS_LOG1("-");
        DS_LOG1("+");
    }
    DS_LOG1("\n");
    
    return 0;
}

int Mnist::_get_labels(int bid, int bsz) {
    int hdr = sizeof(U32) * 2;                     ///< header to skip over
    
    if (!label) DS_ALLOC(&label, bsz);

    t_in.seekg(hdr + bid * bsz);                   /// * seek by batch
    t_in.read((char*)label, bsz);                  /// * fetch batch labels
    eof |= t_in.eof();                             /// * set EOF flag
    
    int cnt = eof ? d_in.gcount() : bsz;
    
    return cnt;
}

int Mnist::_get_images(int bid, int bsz) {
    int hdr = sizeof(U32) * 4;                     ///< header to skip over
    int xsz = bsz * dsize();                       ///< image block size
    
    if (!data) DS_ALLOC(&data, xsz);

    d_in.seekg(hdr + bid * xsz);                   /// * seek by batch id
    d_in.read((char*)data, xsz);                   /// * fetch batch images
    eof |= d_in.eof();                             /// * set EOF flag
    
    int cnt = eof ? d_in.gcount() / dsize() : bsz;

    return cnt;
}


