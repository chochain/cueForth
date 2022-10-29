/** -*- c++ -*-
 * @file
 * @brief Model class - loss and trace functions implementation
 *
 * <pre>Copyright (C) 2022- GreenII, this file is distributed under BSD 3-Clause License.</pre>
 */
#include "model.h"
#include "dataset.h"

#if T4_ENABLE_OBJ
__GPU__ DU
Model::_loss(t4_loss op, Tensor &out, Tensor &hot) {
    const int N = out.N();
    DU  err = DU0;                   ///> result loss value
    switch (op) {
    case LOSS_MSE:                   /// * mean squared error, input from linear
        out -= hot;
        err = 0.5 * NORM(out.numel, out.data) / N;
        break;
    case LOSS_CE:                    /// * cross_entropy, input from softmax
        out.map(O_LOG);
        /* no break */
    case LOSS_NLL:                   /// * negative log likelihood, input from log-softmax
        out *= hot;                  /// * hot_i * log(out_i)
        err = -out.sum() / N;        /// * negative average per sample
        break;
    default: ERROR("Model#loss op=%d not supported\n", op);
    }
    // debug(out);
    SCALAR(err);
    return err;
}

__GPU__ Tensor&
Model::onehot() { return *_hot; }

__GPU__ Tensor&
Model::onehot(Dataset &dset) {
    auto show = [](DU *h, int n, int sz) {
        printf("onehot[%d]={", n);
        for (int i = 0; i < sz; i++) {
            printf("%2.0f", h[i]);
        }
        printf("}\n");
    };
    Tensor &out = (*this)[-1];                         ///< model output
    int    N    = out.N(), hwc = out.HWC();            ///< sample size
    Tensor &hot = _t4(N, hwc).fill(DU0);               ///< one-hot vector
    for (int n = 0; n < N; n++) {                      /// * loop through batch
        DU *h = hot.slice(n);                          ///< take a sample
        U32 i = INT(dset.label[n]);
        h[i < hwc ? i : 0] = DU1;
        if (_trace > 0) show(h, n, hwc);
    }
    return hot;
}

__GPU__ DU
Model::loss(t4_loss op) {
    return loss(op, *_hot);                     /// * use default one-hot vector
}
__GPU__ DU
Model::loss(t4_loss op, Tensor &hot) {          ///< loss against one-hot
    Tensor &out = (*this)[-1];                  ///< model output
    if (!out.is_same_shape(hot)) {              /// * check dimensions
        ERROR("Model#loss hot dim != out dim\n");
        return;
    }
    Tensor &tmp = _mmu->copy(out);              ///< non-destructive
    DU err = _loss(op, tmp, hot);               /// * calculate loss
    _dump(tmp.data, tmp.W(), tmp.H(), 1);
    _mmu->free(tmp);                            /// * free memory

    return err;
}
///
/// Stochastic Gradiant Decent
/// Note: does not get affected by batch size
///       because filters are fixed size
///
__GPU__ Model&
Model::sgd(DU lr, DU m, bool zero) {
    Tensor &n1 = (*this)[1];                   ///< reference model input layer
    DU     t0  = _mmu->ms();                   ///< performance measurement
    ///
    /// cascade execution layer by layer forward
    ///
    const int N = n1.N();                      ///< batch size
    auto update = [this, N, lr, m, zero](const char nm, Tensor &f, Tensor &df) {
        TRACE1(" %c[%d,%d,%d,%d]", nm, f.N(), f.H(), f.W(), f.C());
        if (m < DU_EPS) {
            df *= lr / N;                          /// * learn rate / batch size
            f  -= df;                              /// * w -= eta * df
        }
        else {                                     /// * with momentum (exp moving avg)
            df *= (1 - m) * lr / N;                /// * w' = m * w - (1 - m) * eta * df
            f  *= m;
            f  -= df;
        }
        if (zero) df.map(O_FILL, DU0);         /// * zap df, ready for next batch
    };
    TRACE1("\nModel#sgd batch_sz=%d, lr=%6.3f, mtum=%6.3f", N, lr, m);
    for (U16 i = 1; i < numel - 1; i++) {
        Tensor &in = (*this)[i];

        TRACE1("\n%2d> %s ", i, d_nname(in.grad_fn));
        if (in.grad[2]) {
            TRACE1(" dfΣ=%6.3f", in.grad[2]->sum());
            update('f', *in.grad[0], *in.grad[2]);
        }
        if (in.grad[3]) {
            TRACE1(" dbΣ=%6.3f", in.grad[3]->sum());
            update('b', *in.grad[1], *in.grad[3]);
        }
        if (in.grad[0]) TRACE1(" => fΣ=%6.3f", in.grad[0]->sum());
        if (in.grad[1]) TRACE1(" bΣ=%6.3f",    in.grad[1]->sum());
    }
    TRACE1("\nModel#sgd %5.2f ms\n", _mmu->ms() - t0);
    return *this;
}

__GPU__ Model&
Model::adam(DU lr, DU b0, DU b1, bool zero) {
    return *this;
}
#endif  // T4_ENABLE_OBJ
//==========================================================================
