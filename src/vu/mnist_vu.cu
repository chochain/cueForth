/** -*- c++ -*-
 * @File
 * @brief - tensorForth MNIST Dataset Vu (Texture builder)
 *
 * <pre>Copyright (C) 2022- GreenII, this file is distributed under BSD 3-Clause License.</pre>
 */
#ifndef TEN4_SRC_VU_MNIST_VU_H
#define TEN4_SRC_VU_MNIST_VU_H
#include "vu.h"
///
/// MNIST GUI texture builder
///
class MnistVu : public Vu {
    int NX, NY;
public:
    MnistVu(Dataset &ds, int nx=40, int ny=30) :
        Vu(ds, ds.W * nx, ds.H * ny), NX(nx), NY(ny) {}
    
    virtual int init_host_texture() {
        auto fit = [this](int z0, unsigned char *src) {
            uchar4 *t = &h_tex[z0];
            for (int i = dset.H - 1; i >= 0; i--) {      // y top-down flip
                for (int j = 0; j < dset.W; j++, src++) {
                    int z = j + i * dset.W * NX;
                    t[z].x = t[z].y = t[z].z = *src;
                    t[z].w = 0xff;
                }
            }
        };
        for (int y = 0, y1 = NY-1; y < NY; y++, y1--) { // y1 top-down flip
            printf("\n");
            for (int x = 0; x < NX; x++) {
                int z   = x + y * NX;
                U8 *src = dset[z];
                int z0  = (x + y1 * dset.H * NX) * dset.W;
                fit(z0, src);
                printf("%1d", dset.h_label[z]);
            }
        }
        printf("\n");
        return 0;
    }
};
#endif  // TEN4_SRC_VU_MNIST_VU_H



