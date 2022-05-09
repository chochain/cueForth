/*! @file
  @brief
  cueForth - eForth core classes
*/
#ifndef CUEF_SRC_EFORTH_H
#define CUEF_SRC_EFORTH_H
#include "cuef_types.h"
#include "util.h"
#include "vector.h"         // cueForth vector
#include "aio.h"            // cueForth async IO (Istream, Ostream)

#define ENDL            "\n"
#define millis()        clock()
#define delay(ms)       { clock_t t = clock()+ms; while (clock()<t); }
#define yield()
///
/// Forth virtual machine class
///
typedef enum { VM_READY=0, VM_RUN, VM_WAIT, VM_STOP } vm_status;

class Dict;
class ForthVM {
public:
    vm_status     status = VM_READY;        /// VM status
    DU    top     = DU0;                    /// cached top of stack
    Vector<DU,   CUEF_RS_SZ>   rs;          /// return stack
    Vector<DU,   CUEF_SS_SZ>   ss;          /// parameter stack

    __GPU__ ForthVM(Istream *istr, Ostream *ostr, MMU *mmu);
    __GPU__ void init();
    __GPU__ void outer();

private:
    Istream       &fin;                     /// VM stream input
    Ostream       &fout;                    /// VM stream output
    MMU           &mmu;                     /// memory managing unit

    bool  ucase   = true;                   /// case insensitive
    bool  compile = false;                  /// compiling flag
    int   radix   = 10;                     /// numeric radix
    IU    WP      = 0;                      /// word and parameter pointers
    U8    *PMEM0, *IP0, *IP;                /// cached base-memory pointer

    char  idiom[CUEF_STRBUF_SZ];            /// terminal input buffer

    __GPU__ DU   POP()        { DU n=top; top=ss.pop(); return n; }
    __GPU__ DU   PUSH(DU v)   { ss.push(top); top = v; }

    __GPU__ int  find(const char *s);      /// search dictionary reversely
    ///
    /// Forth inner interpreter
    ///
    __GPU__ char *next_word();
    __GPU__ char *scan(char c);
    __GPU__ void nest(IU c);
    ///
    /// compiler proxy funtions to reduce verbosity
    ///
    __GPU__ void add_iu(IU i);
    __GPU__ void add_du(DU d);
    __GPU__ void add_str(IU op, const char *s);
    __GPU__ void call(IU w);
    ///
    /// debug functions
    ///
    __GPU__ void dot_r(int n, DU v);
    __GPU__ void ss_dump(int n);
};
#endif // CUEF_SRC_EFORTH_H
