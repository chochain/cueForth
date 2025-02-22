/**
 * @file
 * @brief TensorVM class , extended ForthVM classes, tensor handler interface
 *
 * <pre>Copyright (C) 2022- GreenII, this file is distributed under BSD 3-Clause License.</pre>
 */
#ifndef TEN4_SRC_TENVM_H
#define TEN4_SRC_TENVM_H
#include "eforth.h"                         /// extending ForthVM

#if T4_ENABLE_OBJ
#define VLOG1(...) if (sys.trace() > 0) INFO(__VA_ARGS__);
#define VLOG2(...) if (sys.trace() > 1) INFO(__VA_ARGS__);
///
///@name multi-dispatch checker macros
///@{
#define TTOS      ((Tensor&)mmu.du2obj(tos))        /**< tensor on TOS      */
#define TNOS      ((Tensor&)mmu.du2obj(ss[-1]))     /**< tensor on NOS      */
#define TOS1T     (IS_OBJ(tos) && TTOS.is_tensor())
#define TOS2T     (ss.idx > 0 && TOS1T && IS_OBJ(ss[-1]) && TNOS.is_tensor())
#define TOS3T     (ss.idx > 1 && TOS2T && IS_OBJ(ss[-2]) && mmu.du2obj(ss[-2]).is_tensor())
typedef enum {
    T_DROP = 0,
    T_KEEP
} t4_drop_opt;
///@}
///@name Tensor (multi-dimension array) class
///@{
class TensorVM : public ForthVM {
public:
    __GPU__ TensorVM(int id, System &sys) : ForthVM(id, sys) {
        VLOG1("\\    ::TensorVM[%d](...) sizeof(Tensor)=%ld\n", id, sizeof(Tensor));
    }
    __GPU__ virtual void init();            ///< override ForthVM.init()
    
protected:
    int    ten_lvl = 0;                     ///< tensor input level
    int    ten_off = 0;                     ///< tensor offset (storage index)
    ///
    /// override literal handler
    ///
    __GPU__ virtual int number(char *str);  ///< TODO: CC - worked without 'final', why?
    ///
    /// tensor ops based on number of operands
    ///
    __GPU__ void xop1(math_op op, DU v=DU0);                ///< 1-operand ops in-place
    __GPU__ void xop2(math_op op, t4_drop_opt x=T_KEEP);    ///< 2-operand ops
    __GPU__ void xop1t(t4_ten_op op);                       ///< 1-operand ops with new tensor
    __GPU__ void xop2t(t4_ten_op op, t4_drop_opt x=T_KEEP); ///< 2-operand tensor ops
    
private:
    ///
    /// tensor ops based on data types
    ///
    __GPU__ void   _ss_op(math_op op);                      ///< scalar-scalar (eForth) ops
    __GPU__ Tensor &_st_op(math_op op, t4_drop_opt x);      ///< scalar tensor op (broadcast)
    __GPU__ Tensor &_ts_op(math_op op, t4_drop_opt x);      ///< tensor scalar op (broadcast)
    __GPU__ Tensor &_tt_op(math_op op);                     ///< tensor tensor op
    ///
    /// tensor-tensor ops
    ///
    __GPU__ Tensor &_tinv(Tensor &A);                       ///< matrix inversion
    __GPU__ Tensor &_tdot(Tensor &A, Tensor &B);            ///< matrix-matrix multiplication @
    __GPU__ Tensor &_tdiv(Tensor &A, Tensor &B);            ///< matrix-matrix division (no broadcast)
    __GPU__ Tensor &_solv(Tensor &A, Tensor &B);            ///< solve linear equation Ax = b
    __GPU__ void   _gemm();                                 ///< GEMM C' = alpha * A x B + beta * C
    ///
    /// tensor IO
    ///
    __GPU__ void   _pickle(bool save);                      ///< save/load a tensor to/from a file
};
///@}

#endif // T4_ENABLE_OBJ
#endif // TEN4_SRC_TENVM_H
