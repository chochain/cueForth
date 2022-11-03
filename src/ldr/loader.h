/** -*- c++ -*-
 * @file
 * @brief Loader class - dataset loader factory interface
 *
 * <pre>Copyright (C) 2022- GreenII, this file is distributed under BSD 3-Clause License.</pre>
 */
#ifndef TEN4_LOADER_H
#define TEN4_LOADER_H
#include "corpus.h"

struct Loader {
    static void   init(bool trace);
    static Corpus *get(int dset, const char *ds_name=NULL);
};
#endif  // TEN4_LOADER_H


