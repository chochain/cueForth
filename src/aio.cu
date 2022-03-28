/*! @file
  @brief
  cueForth Async IO module implementation

  <pre>
  Copyright (C) 2021- GreenII

  This file is distributed under BSD 3-Clause License.

  </pre>
*/
#include <cstdio>
#include "aio.h"

__GPU__ __managed__ Istream *_istr;
__GPU__ __managed__ Ostream *_ostr;
obuf_node *_root;
bool      _trace;

__KERN__ void
_aio_setup(char *ibuf, char *obuf) {
	if (threadIdx.x!=0 || blockIdx.x!=0) return;
	_istr = new Istream(ibuf);
	_ostr = new Ostream(obuf);
}

__KERN__ void
_aio_clear() {
	if (threadIdx.x!=0 || blockIdx.x!=0) return;
	_ostr->clear();
}
///
/// AIO takes managed memory blocks as input and output buffers
/// which can be access by both device and host
///
Istream *AIO::istream() { return _istr; }
Ostream *AIO::ostream() { return _ostr; }

__HOST__ void
AIO::init(char *ibuf, char *obuf, bool trace) {
	_aio_setup<<<1,1>>>(ibuf, obuf);

    _root  = (obuf_node*)obuf;                   // host buffer root
    _trace = trace;
}

__HOST__ obuf_node*
AIO::_print_node(obuf_node *node) {
    U8 buf[80];                                 // check buffer overflow

    if (_trace) printf("<%d>", node->id);

    switch (node->gt) {
    case GT_INT:
        printf("%d", *((GI*)node->data));
        break;
    case GT_HEX:
        printf("%x", *((GI*)node->data));
        break;
    case GT_FLOAT:
        printf("%g", *((GF*)node->data));
        break;
    case GT_STR:
        memcpy(buf, (U8*)node->data, node->size);
        printf("%s", (U8*)buf);
        break;
    default: printf("print node type not supported: %d", node->gt); break;
    }
    if (_trace) printf("</%d>\n", node->id);

    return node;
}

#define NEXTNODE(n) ((obuf_node *)(node->data + node->size))
__HOST__ void
AIO::flush() {
    obuf_node *node = _root;
    while (node->gt != GT_EMPTY) {          // 0
        node = _print_node(node);
        node = NEXTNODE(node);
    }
    _aio_clear<<<1,1>>>();
}
