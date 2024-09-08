#import "@preview/polylux:0.3.1": *
#import "@preview/fletcher:0.3.0" as fletcher: node, edge
#import "theme/ctu.typ": *

#show: ctu-theme.with()

#let light(content) = {
  text(fill: gray, content)
}

#let accent(content) = {
  text(fill: theme.accent, content)
}

#let imp(content) = {
  text(fill: red, content)
}


#title-slide[
    #set text(size: 1.3em)
  
    #v(6em)

    = Borrowing Polonius
    
    Jakub Dupák
  

    #v(2em)

    #text(size: 0.7em)[
      GNU Tools Cauldron 2024
      
      16. 9. 2024
    ]
]

#title-slide[
  #set text(size: 5em, weight: "bold")
  Rust?!

    #notes(
    ```md
    Protože analýza celého programu by měla extrémní výpočetní nároky, provádí borrow checker pouze analýzu uvnitř funkce.

    Na hranicích funkce musí programátor popsat popsat invarianty platnosti referencí a to pomocí lifetime anotací, na slidu apostrof `a` a apostrof `b`.

    Na příkladu zde máme vektor referencí, jejihž platnost v rámci programu je zdola omezena regionem apostrof `a`. Pokud chceme vložit fo vektoru novou referenci s platností apostrof `b`, musíme říci, že oblast programu apostrof `b` je alespoň tak velká, jako apostrof `a`.

    Zde na konrétním příkladu, můžete vidět dosazené časti programu.
    ```
  )
]

#title-slide[
  #set text(size: 4em, weight: "bold")
  #rotate(box(box([MEMORY SAFETY], stroke: theme.accent.lighten(10%) + 4pt, inset: 15pt, radius: 20pt), stroke: theme.accent.lighten(10%) + 4pt, inset: 6pt, radius: 20pt), -15deg)
  
]

#title-slide[
  #image("media/gccrs.png", height: 12em)
]

#title-slide[
  #move(dx: 29%, dy: -30%)[#image("media/thought-bubble.svg", height: 100%)]
  #v(-55%)
  #move(dx: -25%, dy: 0%)[#image("media/gccrs.png", height: 9em)]
  #set text(size: 3.3em, weight: "bold",)
  #place(top+right, dy: 50pt, dx: -10pt, align(left, [Memory \ safety???]))
]

#title-slide[
  #set text(size: 4em, weight: "bold")
  #only(1)[#place(horizon+left, dy: -30pt, dx: 60pt, image("media/rust.svg", height: 40%))]
  #uncover(2)[#text(fill: black, [&])#text(fill: gray, [mut])] Polonius
  #uncover(2)[
      #v(-10%)
      #move(dx: 0%, dy: 0%)[#image("media/gccrs.png", height: 30%)]
      #v(-30%)
  ]
]

#slide[
  = Outline

  - About me
  - Borrow checker rules
  - History of borrow checking
    - Lexical
    - NLL
    - Polonius
  - Rust GCC
    - BIR
    - Polonius engine
]

#slide[
  = About Me

  #grid(columns: (100pt, 1fr), column-gutter: 30pt, row-gutter: 50pt,
  [#image("media/me.jpg", width: 100pt, height: 100pt, fit: "cover")],
  [
    *Jakub Dupák* \
    #text(size: 0.85em, [#light([_#link("mailto:dev@jakubdupak.com", "dev@jakubdupak.com")_])]) \
    #text(size: 0.85em, [#light([_#link("https://jakubdupak.com")_])])
  ],
  only("2-")[#image("media/cvut-symbol.svg", height: 100pt)],
  only("2-")[
     #text(fill: rgb("#0065BD"), [
       *Memory safety analysis in Rust GCC* \
       #light([#smallcaps("Faculty of Electrical Engineering")]) \
       #text(size: 0.85em, [#light([_#link("https://dspace.cvut.cz/handle/10467/113390")_])])
     ])
  ],
  only("3-")[#image("media/ms.svg", height: 100pt)],
  only("3-")[
     #text(fill: gray, [
       *Software Engineer* \
       #light([#smallcaps("Rust Tooling Group at MDCP")]) \
       #text(size: 0.85em, [#light([_Microsoft Development Center Prague_])])
     ])
  ],)
]

#title-slide[
  = Borrow Checker Rules
]

#slide[
  = High-level Rules
 
  #set text(size: 1.5em, weight: "bold")
  #set align(center+horizon)

  
  #light([#sym.section 1]) \
  No invalid memory access

  #v(10pt)

  #light([#sym.section 2]) \
  No mutable reference aliasing
]

#slide[
  == #light([#sym.section 1]) No invalid memory access

  - Move
  #only(2)[
    ```rust
      let mut v1 = Vec::new();
      v1.push(42)
      let mut v2 = v1; // <- Move
      println!(v1[0]); // <- Error
    
    ```
    #v(0.5em)
  ]
  #only("1-")[
    - Borrow must not outlive borrowee
    - Lifetime subset relation
  ]

    #only(3)[
     ```rust
      fn f() -> &i32 {
        &(1+1)
      } // <- Error
     ```
    #v(0.5em)
  ]
]

#slide[
  == #light([#sym.section 2]) No mutable reference aliasing

  - #light([Either]) one mutable reference \ #light([or]) multiple (shared) immutable reference
    #only(2)[
      ```rust
        let mut counter = 0;
        let ref1 = &mut counter;
        // ...
        let ref2 = &mut counter; //  <- Error
      ```
    ]
  
    - No modification of borrowed data

]

#slide[
  = Checking Functions

  #only(1)[```rust
  fn magic(a: &i32) -> &i32;
  ```]

  #only(2)[```rust
  fn magic(a: &i32) -> &i32 {
    a
  }
  ```]

  #only(3)[```rust
  fn magic(a: &i32) -> &i32 {
    &(1+1)
  }
  ```]

  #only(4)[```rust
  fn magic(a: &i32) -> &i32 {
    &GLOBAL_I32
  }
  ```]

  #only(5)[```rust
  fn magic(a: &i32) -> &i32 {
    if (random()) {
      &GLOBAL_I32
    } else {
      a
    }
  }
  ```]

  #only(6)[```rust
  fn magic(a: &i32, b: &i32) -> &i32 {
    if (random()) {
      a
    } else {
      b
    }
  }
  ```]


  #only(7)[```rust
  struct Vec<&'a i32> { ... }

  impl<'a> Vec<&'a i32> {
    fn push<'b>
       where 'b: 'a (&mut self, x: &'b i32) {
      // ...
    }
  }
  ```]

    #notes(
    ```md
    Protože analýza celého programu by měla extrémní výpočetní nároky, provádí borrow checker pouze analýzu uvnitř funkce.

    Na hranicích funkce musí programátor popsat popsat invarianty platnosti referencí a to pomocí lifetime anotací, na slidu apostrof `a` a apostrof `b`.

    Na příkladu zde máme vektor referencí, jejihž platnost v rámci programu je zdola omezena regionem apostrof `a`. Pokud chceme vložit fo vektoru novou referenci s platností apostrof `b`, musíme říci, že oblast programu apostrof `b` je alespoň tak velká, jako apostrof `a`.

    Zde na konrétním příkladu, můžete vidět dosazené časti programu.
    ```
  )
]

#title-slide[
  = Borrow checker evolution

  Lexical, NLL, Polonius
]

#slide[
  = Lexical borrow checker

    #align(center + horizon)[#text(size: 2em, weight: "bold", [
    lifetime = lexical scope#imp("*")
  ])]
]

#slide[
  = Lexical borrow checker

  #only(1)[
    ```rust
      fn foo() {
        let mut data = vec!['a', 'b', 'c'];
        capitalize(&mut data[..]);         
        data.push('d');
        data.push('e');
        data.push('f');
      }
    ```
  ]
  
  #only(2)[
      ```rust
        fn foo() {
          let mut data = vec!['a', 'b', 'c']; // --+
          capitalize(&mut data[..]);          //   |
          // ^~~~~~~~~~~~~~~~~~~~~~ 'lifetime //   |
          data.push('d');                     //   |
          data.push('e');                     //   |
          data.push('f');                     //   |
        } // <-------------------------------------+
      ```
  ]
]

#slide[
  = Lexical borrow checker

  ```rust
    fn bar() {
      let mut data = vec!['a', 'b', 'c'];
      let slice = &mut data[..]; // <-+ 
      capitalize(slice);         //   |
      data.push('d'); // ERROR!  //   |
      data.push('e'); // ERROR!  //   |
      data.push('f'); // ERROR!  //   |
    } // <----------------------------+
  ```
]

#slide[
  = Lexical borrow checker

  ```rust
  fn process_or_default() {
    let mut map = ...;
    let key = ...;
    match map.get_mut(&key) { // -------------+
        Some(value) => process(value),     // |
        None => {                          // |
            map.insert(key, V::default()); // |
            //  ^~~~~~ ERROR               // |
        }                                  // |
    }; // <-----------------------------------+
  }
  ```
]

#slide[
  = Non-lexical lifetimes (NLL)

    #align(center + horizon)[#text(size: 2em, weight: "bold", [
    lifetime = set of CFG nodes
  ])]
]

#slide[
  = Non-lexical lifetimes (NLL)


  #grid(columns: (4fr, 1fr))[
    ```rust
    fn f<'a>(map: &'r mut HashMap<K, V>)
    {
      ...
      match map.get_mut(&key) {
        Some(value) => process(value),
        None => {
          map.insert(key, V::default());
        }
      }
    }
    ```
  ][
    #set text(size: 0.75em, font: "Roboto Mono")

    #only(1)[
    #fletcher.diagram(
      {
      let (start, match, s, n, end, ret) = ((0,0), (0,-1), (-0.5, -2), (0.5, -2), (0, -3), (0, -4))
      node(start, "Start")
      node(match, "Match")
      node(s, "Some")
      node(n, "None")
      node(end, "End")
      node(ret, "Return")
      edge(start, match, "->")
      edge(match, s, "->")
      edge(match, n, "->")
      edge(s, end, "->")
      edge(n, end, "->")
      edge(end, ret, "->")
    })]
    #only("2-")[
    #fletcher.diagram(
      {
      let (start, match, s, n, end, ret) = ((0,0), (0,-1), (-0.5, -2), (0.5, -2), (0, -3), (0, -4))
      node(start, "Start")
      node(match, text(fill:blue, "Match"))
      node(s, text(fill:green, "Some"))
      node(n, text(fill:red, "None"))
      node(end, text(fill:red, "End"))
      node(ret, "Return")
      edge(start, match, "->")
      edge(match, s, "->")
      edge(match, n, "-->")
      edge(s, end, "-->")
      edge(n, end, "-->")
      edge(end, ret, "-->")
    })]
  ]

      #only(3)[
      === NLL #sym.arrow lifetimes are CFG nodes
    ]
]

#slide[
  = Breaking NLL
  
  #grid(columns: (3fr, 1fr))[
    #let c = ```rust
      fn f<'a>(map: &'a mut Map<K, V>) -> &'a V {
        ...
        match map.get_mut(&key) {
          Some(value) => process(value),
          None => {
            map.insert(key, V::default())
          }
        }
      }
    ```

    #only(1, code((1,8), c))
    #only(2, code((3,), c))
    #only(3, code((3,4), c))
    #only(4, code((3,4,8), c))
    #only(5, code((1,3,4,8,9), c))
    #only(6, code((5,6,7), c))
    #only(6)[ === Error! ]
  ][
    #set text(size: 0.75em, font: "Roboto Mono")

    #let cfg(step) = {
      fletcher.diagram(
      {
      let (start, match, s, n, end, ret) = ((0,0), (0,-1), (-0.5, -2), (0.5, -2), (0, -3), (0, -4))
      node(start, text(fill: if step >= 5 { red } else { black }, "Start"))
      node(match, text(fill: if step >= 2 { red } else { black }, "Match"))
      node(s, text(fill: if step >= 3 { red } else { black },"Some"))
      node(n, text(fill: if step >= 5 { red } else { black },
        weight: if step >= 6 { 900 } else { "regular" }
       ,"None"))
      node(end, text(fill: if step >= 4 { red } else { black}, "End"))
      node(ret, text(fill: if step >= 4 { red } else { black},"Return"))
      edge(start, match, "->")
      edge(match, s, "->")
      edge(match, n, "->")
      edge(s, end, "->")
      edge(n, end, "->")
      edge(end, ret, "->")
    })}

    #for step in range(7) {
        only(step, cfg(step))
    }
  ]
]

#slide[
  = Polonius

  #align(center + horizon)[#text(size: 2em, weight: "bold", [
    Lifetime = set of loans
  ])]
]

#slide[
  = Polonius

    #grid(columns: (3fr, 1fr))[
    #let c = ```rust
      fn f<'a>(map: Map<K, V>) -> &'a V {
        ...
        match map.get_mut(&key) {
          Some(value) => process(value),
          None => {
            map.insert(key, V::default());
          }
        }
      }
    ```

    #only(1, code((5,6,7), c))
  ][
    #set text(size: 0.75em, font: "Roboto Mono")

    #let cfg(step) = {
      fletcher.diagram(
      {
      let (start, match, s, n, end, ret) = ((0,0), (0,-1), (-0.5, -2), (0.5, -2), (0, -3), (0, -4))
      node(start, text(fill: if step >= 5 { red } else { black}, "Start"))
      node(match, text(fill: if step >= 2 { red } else { black}, "Match"))
      node(s, text(fill: if step >= 3 { red } else { black},"Some"))
      node(n, text(fill: if step >= 5 { red } else { black},"None"))
      node(end, text(fill: if step >= 4 { red } else { black}, "End"))
      node(ret, text(fill: if step >= 4 { red } else { black},"Return"))
      edge(start, match, "->")
      edge(match, s, "->")
      edge(match, n, "->")
      edge(s, end, "->")
      edge(n, end, "->")
      edge(end, ret, "->")
    })}

    #for step in range(2) {
        only(step, cfg(step))
    }
  ]
]

#slide[
  = Polonius

  ```rust
    let r: &'0 i32 = if (cond) {
      &x /* Loan L0 */
    } else {
      &y /* Loan L1 */
    };
  ```
]

#title-slide[
  = Computing!

  Steps of the borrow checker
]

#slide[
  = What do we need?

  #only(1)[ #box(width: 100%, height: 100%, clip: true, inset: (top: 0pt), align(center, image("media/polonius.svg", height: 100%))) ]
  #only(2)[ #box(width: 100%, height: 100%, clip: true, inset: (top: 0pt), align(center, image("media/polonius.svg", height: 200%))) ]
  #only(3)[ #box(width: 100%, height: 100%, clip: true, inset: (top: -50%, bottom: 50%), align(center, image("media/polonius.svg", height: 200%))) ]
  #only(4)[ #box(width: 100%, height: 100%, clip: true, inset: (top: -100%, bottom: 100%), align(center, image("media/polonius.svg", height: 200%))) ]
  #only(5)[ #box(width: 100%, height: 100%, clip: true, inset: (top: 0pt), align(center, image("media/polonius.svg", height: 100%))) ]
]

#title-slide[
  = What about lifetime annotations?

  ```rust
  let x: &'a i32;
  ```
]

#slide[
  = Lifetime annotations everywhere

  #only(1, ```rust
    fn max_ref(a: &i32, b: &i32) -> &i32 {
      let mut max = a;
      if (*max < *b) {
        max = b;
      }
      max
    }
  ```)
  #only(2, code((1,),```rust
    fn max_ref(a: &'a i32, b: &'a i32) -> &'a i32 {
      let mut max = a;
      if (*max < *b) {
        max = b;
      }
      max
    }
  ```))
  #only(3, code((1,),```rust
    fn max_ref(a: &'a i32, b: &'b i32) -> &'c i32 {
      let mut max = a;
      if (*max < *b) {
        max = b;
      }
      max
    }
  ```))
  #only(4, code((2,),```rust
    fn max_ref(a: &'a i32, b: &'b i32) -> &'c i32 {
      let mut max: &i32 = a;
      if (*max < *b) {
        max = b;
      }
      max
    }
  ```))
  #only(5, {
    code((2,3,4,5,5,6),```rust
    fn max_ref(a: &'a i32, b: &'b i32) -> &'c i32 {
      let mut max: &'?1 i32 = a;
      if (*max < *b) {
        max = b;
      }
      max
    }
  ```)
  set align(horizon + center)
  set text(size: 1.5em, )
  table(columns: 2, column-gutter: 50pt, row-gutter: 10pt,  stroke: none, 
    [`max = a`],[ `'a: '?1` ],
    [`max = b`], [ `'b: '?1` ],
    [`return max`], [ `'?1: 'c` ],
  )
})
]

#slide[
    #only(1)[ #box(width: 100%, height: 100%, clip: true, inset: (top: -50%, bottom: 50%), align(center, image("media/polonius.svg", height: 200%))) ]

]

#title-slide[
  = Back to Rust GCC

  BIR, Variance, Polonius, Future
]

#slide[
  = Rust GCC

  #set align(center+horizon)
  #image("media/pipeline.svg", height: 100%)
]

#slide[
  == MIR

  ```rust
    struct Foo(i32);
  
    fn foo(x: i32) -> Foo {
        Foo(x)
    }
  ```
]

#slide[
  == MIR

    ```rust
    fn foo(_1: i32) -> Foo {
        debug x => _1;
        let mut _0: Foo;
    
        bb0: {
            _0 = Foo(_1);
            return;
        }
    }
  ```
]

#slide[
  === MIR: Fibonacci

  #set text(size: 0.5em)

  #columns(2, gutter: 11pt)[
  ```rust
  fn fib(_1: u32) -> u32 {
    bb0: {
      StorageLive(_2);
      StorageLive(_3);
      _3 = _1;
      _2 = Eq(move _3, const 0_u32);
      switchInt(move _2) -> [0: bb2, otherwise: bb1];
    }
    bb2: {
      StorageDead(_3);
      StorageLive(_4);
      StorageLive(_5);
      _5 = _1;
      _4 = Eq(move _5, const 1_u32);
      switchInt(move _4) -> [0: bb4, otherwise: bb3];
    }
    bb5: {
      _7 = move (_9.0: u32);
      StorageDead(_8);
      _6 = fib(move _7) -> [return: bb6, unwind: bb11];
    }
    bb7: {
      _11 = move (_13.0: u32);
      StorageDead(_12);
      _10 = fib(move _11) -> [return: bb8, unwind: bb11];
    }
    bb8: {
      StorageDead(_11);
      _14 = CheckedAdd(_6, _10);
      assert(!move (_14.1: bool)) -> [success: bb9, unwind: bb11];
    }
    bb9: {
      _0 = move (_14.0: u32);
      StorageDead(_10);
      StorageDead(_6);
      goto -> bb10;
    }
    bb10: {
      StorageDead(_4);
      StorageDead(_2);
      return;
    }
    bb11 (cleanup): {
      resume;
    }
  }
  ```]
]

#slide[
  = Rust GCC

  #set align(center+horizon)
  #image("media/pipeline.svg", height: 100%)
]

#slide[
  = Rust GCC

  #set align(center+horizon)
  #image("media/bir.svg")
]

#slide[
  == BIR: Borrow Checker IR

  #set text(size: 0.6em)

  - basic block list
    - basic block
      - `Statement`
      - `Assignment`
      - `InitializerExpr`
      - `Operator<ARITY>`
      - `BorrowExpr`
      - `AssignmentExpr (copy)`
      - `CallExpr`
      - `Switch`
      - `Goto`
      - `Return`
      - `StorageLive` (start of variable scope)
      - `StorageDead` (end of variable scope)
      - `UserTypeAsscription` (explicit type annotation)
   - place database
   - arguments
   - return type
   - universal lifetimes
   - universal lifetime constraints
]

#slide[
  === BIR: Fibonacci

  #set text(size: 0.55em)

  #columns(2, gutter: 11pt)[

  ```rust
  fn fib(_2: u32) -> u32 {
    bb0: {
        StorageLive(_3);
        StorageLive(_5);
        _5 = _2;
        StorageLive(_6);
        _6 = Operator(move _5, const u32);
        switchInt(move _6) -> [bb1, bb2];
    }

    bb1: {
        _3 = const bool;
        goto -> bb3;
    }

    bb2: {
        StorageLive(_8);
        _8 = _2;
        StorageLive(_9);
        _9 = Operator(move _8, const u32);
        _3 = move _9;
        goto -> bb3;
    }

    bb3: {
        switchInt(move _3) -> [bb4, bb5];
    }

    bb4: {
        _1 = const u32;
        goto -> bb8;
    }

    bb5: {
        StorageLive(_14);
        _14 = _2;
        StorageLive(_15);
        _15 = Operator(move _14, const u32);
        StorageLive(_16);
        _16 = Call(fib)(move _15) -> [bb6];
    }

    bb8: {
        return;
    }
}
  ```]
]

#slide[
  == Facts colector

  #set text(size: 0.8em)

  ```
  <Origin, Loan, Point>       loan_issued_at
  Origin                      universal_region
  <Point, Point>              cfg_edge
  <Loan, Point>               loan_killed_at
  <Origin, Origin, Point>     subset_base
  <Point, Loan>               loan_invalidated_at
  <Variable, Point>           var_used_at
  <Variable, Point>           var_defined_at
  <Variable, Point>           var_dropped_at
  <Variable, Origin>          use_of_var_derefs_origin
  <Variable, Origin>          drop_of_var_derefs_origin
  <Path, Path>                child_path
  <Path, Variable>            path_is_var
  <Path, Point>               path_assigned_at_base
  <Path, Point>               path_moved_at_base
  <Path, Point>               path_accessed_at_base
  <Origin, Origin>            known_placeholder_subset
  <Origin, Loan>              placeholder
  ```
]

#slide[
  == Generics and Variance

  #set text(size: .9em)

  #only("1")[
  ```rust
    let a: &?1 i32;
    let b: &?2 i32;
    /// ...
    a = b;
  ```]

  #only("2-")[
    ```rust
      let a: Foo</*???*/>;
      let b: Foo</*???*/>;
      /// ...
      a = b;
    ```]

  \

  #only("3-")[
    ```rust
      struct Foo<'a, 'b, T> {
        x: &'a T,
        y: Bar<T>,
      }
    ```]
]

#slide[
  = Bootstraping

  - Polonius is written in advanced Rust
  - Similar problem with proc macros
  - For now
    - Optional component compiled by _rustc_
]

#slide[
  = GSoC 2024

  #grid(columns: (100pt, 1fr), column-gutter: 30pt, row-gutter: 50pt,
  [#image("media/kushal.png", width: 100pt, height: 100pt, fit: "cover")],
  [
    *Borrow-checking IR location support* \
    #text(size: 0.85em, [ Kushal Pal ]) \
    #text(size: 0.85em, [#light([_#link("https://summerofcode.withgoogle.com/programs/2024/projects/DPiEgdZa")_])]) \
    #text(size: 0.85em, [#light([_#link("https://github.com/braw-lee/gsoc-2024/blob/main/README.md")_])])
  ]
  )
]

#slide[
  = Detected Errors

  - Mainly limited by BIR translation
  - Detected
    - Move errors
    - Subset errors
    - Loan errors
]

#slide[
  == Move Errors

  #set text(size: 0.7em)

  ```rust
    fn test_move() {
        struct A {
            i: i32,
        }
        let a = A { i: 1 };
        let b = a;
        let c = a;    
    }    
  ```

  #only(2)[
    ```
      example_2.rs:2:1: error: Found move errors in function test_move
        2 | fn test_move() {
          | ^~
    ```]

  #only(3)[
    ```
      example_2.rs:8:13: error: use of moved value
          7 |     let b = a;
            |             ~
            |             |
            |             value moved here
          8 |     let c = a;
            |             ^
            |             |
            |             moved value used here
    ```]
]

#slide[
  == Loan Errors

  #set text(size: 0.7em)

  ```rust
    fn immutable_borrow_while_mutable_borrowed() {
      let mut x = 0;
      let y = &mut x;                    
      let z = &x;                         
      let w = y;                        
    }
  ```

  #only(2)[
    ```
      example_1.rs:2:1: error: Found loan errors in function immutable_borrow_while_mutable_borrowed
      2 | fn immutable_borrow_while_mutable_borrowed() {
        | ^~
    ```]

  #only(3)[
    ```
      example_1.rs:5:13: error: use of borrowed value
        4 |     let y = &mut x;
          |             ~
          |             |
          |             borrow occurs here
        5 |     let z = &x;
          |             ^
          |             |
          |             borrowed value used here
    ```]
]

#slide[
  == Subset Errors

  #set text(size: 0.58em)

  ```rust
    fn complex_cfg_subset<'a, 'b>(b: bool, x: &'a u32, y: &'b u32) -> &'a u32 {
        if b {    
            y    
        } else {    
            x    
        }    
    }
  ```

  #only(2)[
    ```
      example_3.rs:2:1: error: Found subset errors in function complex_cfg_subset. Some lifetime constraints need to be added.
        2 | fn complex_cfg_subset<'a, 'b>(b: bool, x: &'a u32, y: &'b u32) -> &'a u32 {
          | ^~
    ```]

  #only(3)[
    ```
      example_3.rs:2:1: error: subset error, some lifetime constraints need to be added
          2 | fn complex_cfg_subset<'a, 'b>(b: bool, x: &'a u32, y: &'b u32) -> &'a u32 {
            | ^~                    ~~  ~~
            | |                     |   |
            | |                     |   lifetime defined here
            | |                     lifetime defined here
            | subset error occurs in this function
    ```]
]

#slide[
  = Polonius Engine Deprecated

  - Problems with over-materialization
  - Rust Edition 2024
    - Polonius Algorithm
    - NLL Infrastructure'
  - Only minimal part of this work is bound to Polonius engine
]

#slide[
  = TODO

  - Finish translation to BIR
    - Match expressions
    - Two-phase borrowing
    - Drops
  - Collect implicit type constrains
    - `(&'a T => T: 'a)`
  - Improve error messages
    - Store additional information
    - Deduplicate by reason
  - Emit crate metadata
  - #light([(see _#link("https://dspace.cvut.cz/bitstream/handle/10467/113390/F3-DP-2024-Dupak-Jakub-thesis.pdf?sequence=-1&isAllowed=y#section.6.1", "my thesis [section 6.1]")_ for a more detailed list)])
]

#title-slide[
  #move(dy: 6em,image("media/ferris-happy.svg", height: 40%))
  #v(3em)
  #text(size: 3em, weight: 800)[That's all Folks!]
]

#slide[
  = References

  #set text(size: 0.7em, weight: "regular")

  Slides made with Typst and Polylux.

  #set text(size: 0.8em, weight: "regular")

  - DUPAK, Jakub. Memory Safety Analysis in Rust GCC. Available from: _#link("https://dspace.cvut.cz/bitstream/handle/10467/113390/F3-DP-2024-Dupak-Jakub-thesis.pdf")_
  - PAL, Kushal. Google Summer of Code 2024 : Final report. Available from https://github.com/braw-lee/gsoc-2024/blob/main/README.md
  - MATSAKIS, Niko. 2094-nll. In : The Rust RFC Book. Online. Rust Foundation, 2017. [Accessed 18 December 2023]. Available from https: rust-lang.github.io/rfcs/2094-nll.html
  - STJERNA, Amanda. Modelling Rust’s Reference Ownership Analysis Declaratively in Datalog. Online. Master’s thesis. Uppsala University, 2020. [Accessed 28 December 2023]. Available from: https://www.diva-portal.org/smash/get/diva2:1684081/fulltext01.pdf
  - MATSAKIS, Niko, RAKIC, Rémy and OTHERS. The Polonius Book. 2021. Rust Foundation.
  - GJENGSET, Jon.  Crust of Rust: Subtyping and Variance. 2022. [Accessed 19 February 2024]. Available from https://www.youtube.com/watch?v=iVYWDIW71jk
  - Rust Compiler Development Guide. Online. Rust Foundation, 2023. [Accessed 18 December 2023]. Available from https://rustc-dev-guide.rust-lang.org/index.html
  - TOLVA, Karen Rustad. Original Ferris.svg. Available from https://en.wikipedia.org/wiki/File:Original_Ferris.svg
  - TODO

  #light("This work is licensed under CC BY 4.0.") \
  #light([Sources are available at _#link("https://github.com/jdupak/slides-gnu-cauldron-2024-borrowing-polonius")_])
]