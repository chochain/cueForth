/**
 * @file
 * @brief ForthVM class - eForth VM classes interface
 *
 * <pre>Copyright (C) 2022- GreenII, this file is distributed under BSD 3-Clause License.</pre>
 */
#ifndef TEN4_SRC_VM_EFORTH_H
#define TEN4_SRC_VM_EFORTH_H
#include "vm.h"                         ///< VM base class in ../vm
#include "param.h"                      ///< Parameter field

#define USER_AREA  (ALIGN16(MAX_OP))
///
///@name Dictionary Compiler macros
///@note - a lambda without capture can degenerate into a function pointer
///@{
#define ADD_CODE(n, g, im) {           \
    auto f = [this] __GPU__ (){ g; };  \
    mmu->add_word(n, f, im);           \
}
#define CODE(n, g) ADD_CODE(n, g, false)
#define IMMD(n, g) ADD_CODE(n, g, true)
///@}
///@name Data conversion
///@{
#define POPi    (INT(POP()))          /**< convert popped DU as an IU     */
///@}
///
/// Forth Virtual Machine
///
class ForthVM : public VM {
public:
    __GPU__ ForthVM(int id, System *sys);
    
    __GPU__ virtual void init();      ///< override VM
    
protected:
    IU    WP     = 0;                 ///< word pointer
    IU    IP     = 0;                 ///< instruction pointer
    DU    TOS    = -DU1;              ///< cached top of stack
    
    bool  compile= false;
    IU    base   = 0;
    
    Code  *dict  = 0;                 ///< dictionary array (cached)
    U32   *ptos  = (U32*)&TOS;        ///< 32-bit mask for tos
    ///
    /// Forth outer interpreter
    ///
    __GPU__ virtual int resume();             ///< resume suspended work
    __GPU__ virtual int process(char *idiom); ///< process command string
    
private:
    ///
    /// outer interpreter
    ///
    __GPU__ int  parse(char *idiom);          ///< parse command string
    __GPU__ int  number(char *idiom);         ///< parse input as number
    ///
    /// Forth inner interpreter
    ///
    __GPU__ void nest();                      ///< inner interpreter
    __GPU__ void call(IU w);                  ///< execute word by index
    ///
    /// stack short hands
    ///
    __GPU__ __INLINE__ int FIND(char *name) { return mmu->find(name, compile);  }
    __GPU__ __INLINE__ DU  POP()            { DU n=TOS; TOS=SS.pop(); return n; }
    __GPU__ __INLINE__ DU  PUSH(DU v)       { SS.push(TOS); return TOS = v;     }
#if T4_ENABLE_OBJ    
    __GPU__ __INLINE__ DU  PUSH(T4Base &t)  { ss.push(TOS); return TOS = T4Base::obj2du(t); }
#endif // T4_ENABLE_OBJ
    ///
    /// Dictionary compiler proxy macros to reduce verbosity
    ///
    __GPU__ __INLINE__ void add_iu(IU i)   { mmu->add((U8*)&i, sizeof(IU)); }
    __GPU__ __INLINE__ void add_du(DU d)   { mmu->add((U8*)&d, sizeof(DU)); }
    __GPU__ __INLINE__ void add_w(Param p) { add_iu(p.pack); }
    __GPU__ void add_w(IU w) {                ///< compile a word index into pmem
        Code &c = dict[w];
        DEBUG(" add_w(%d) => %s\n", w, c.name);
        Param p(MAX_OP, dict[w].pfa, c.udf);
        add_w(p);
    }
    __GPU__ int  add_str(const char *s, bool adv=true) {
        int sz = STRLENB(s)+1;                ///< calculate string length
        sz = ALIGN(sz);                       /// * then adjust alignment (combine?)
        mmu->add((U8*)s, sz, adv);
        return sz;
    }
    __GPU__ void add_p(                       ///< add primitive word
        prim_op op, IU ip=0, bool u=false, bool exit=false) {
        Param p(op, ip, u, exit);
        add_w(p);
    };
    __GPU__ void add_lit(DU v, bool exit=false) {  ///< add a literal/varirable
        add_p(LIT, 0, false, exit);
        add_du(v);                            /// * store in extended IU
    }
    ///
    /// compiler helpers
    ///
    __GPU__ int  _def_word();                 ///< define a new word
    __GPU__ void _forget();                   ///< clear dictionary
    __GPU__ void _quote(prim_op op);          ///< string helper
    __GPU__ void _to_value();                 ///< update a constant/value
    __GPU__ void _is_alias();                 ///< create alias function
};
#endif // TEN4_SRC_VM_EFORTH_H
