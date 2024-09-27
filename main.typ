#import "@preview/polylux:0.3.1": *
#import "@preview/fletcher:0.3.0" as fletcher: node, edge
#import "theme/ctu.typ": *

#show: ctu-theme.with(aspect-ratio: "4-3")


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
    Let me start question?
    What is the first thing the comes to your mind about the programming language Rust?
    ```
  )
]

#title-slide[
  #set text(size: 4em, weight: "bold")
  #rotate(box(box([MEMORY SAFETY], stroke: theme.accent.lighten(10%) + 4pt, inset: 15pt, radius: 20pt), stroke: theme.accent.lighten(10%) + 4pt, inset: 6pt, radius: 20pt), -15deg)

  #notes(
    ```md
    Memory safety, OK. The Rust compiler, namely the borrow checker, can give your program sort of stamp that your "safe" parts of your program are not doing some nasty things with memory.
    ```
  )
]

#title-slide[
  #image("media/gccrs.png", height: 12em)

  #notes(
    ```md
    You might also have noticed - for example yesterday - that there is an ongoing effort to build an independent Rust compiler in GCC.
    ```
  )
]

#title-slide[
  #move(dx: 29%, dy: -30%)[#image("media/thought-bubble.svg", height: 100%)]
  #v(-55%)
  #move(dx: -25%, dy: 0%)[#image("media/gccrs.png", height: 9em)]
  #set text(size: 3.3em, weight: "bold",)
  #place(top+right, dy: 50pt, dx: -10pt, align(left, [Memory \ safety???]))

  #notes(
    ```md
    You might have noticed - for example yesterday - that there is an ongoing effort to build an independent Rust compiler in GCC. And you cannot really call yourself a Rust compiler if you don't have this borrow checker. Right?
    ```
  )
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

  #notes(
    ```md
    So can Rust GCC give you this stamp as well? Well, unfortunatelly, the answer is "not yet". Rust is a very complex language and it takes a lot of work to compile it.

    However, that official Rust compiler has come up with a new independent library for borrow checking, called Polonius. And we were thinking, couldn't we save ourselves some work and...

    ...borrow this library.
    ```
  )
]

#slide[
  = Outline

  - About me
  - Terminology
  - Borrow checker rules
  - History of borrow checking
    - Lexical
    - NLL
    - Polonius
  - Rust GCC
    - BIR
    - Polonius engine

  #notes(
    ```md
    Well, as you might have guessed, we tried. And I am here today to tell you how it went.

    So let me briefly outline the agenda for this talk:
    - First, I might mention who I am and how I got to this work.
    - Then we will spent a significant time of the presentation trying to unserstand what borrow cheking is all about and why is it hard. This is in my oppinion best understood by looking at the evoluion of the analysis in the official compiler.
    - Finally, with enought background, we will look at Rust GCC and what it take to glue the Polonius Engine to it.
    ```
  )
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
     #text(fill: luma(60%), [
       *Software Engineer* \
       #light([#smallcaps("Rust Tooling Group")]) \
       #text(size: 0.85em, [#light([_Microsoft Development Center Prague_])])
     ])
  ],)

    #notes(
    ```md
    ```
  )
]

#section[
  = Terminology
]

#slide[
  #set align(center+horizon)
  #set text(size: 1.25em)

  == Reference | Borrow

  #set text(size: 2em, weight: "bold")

  _#light[checked pointer]_

  #v(50pt)

  #set text(size: 0.75em)
  
  ```rust
  let reference: &i32;
  ```
]

#slide[
  #set align(center+horizon)
  #set text(size: 1.25em)

  == Borrowing

  #set text(size: 2em, weight: "bold")

  _#light[taking a reference]_

  #v(50pt)

  #set text(size: 0.75em)
  
  ```rust
  &value
  ```
]

#slide-big[
  == Loan
][
  _#light[the result of borrowing]_
][
  ```rust
  &value
  ```
]

#slide-big[
  == Lifetime | Origin | Region
][
  _#light[abstract notion of a part of program]_
][
  range of lines, set of CFG nodes
]

#section[
  = Borrow Checker Rules
]

#slide-big[
  = High-level Rules
][
  #set text(size: 0.8em)
  
  #light([#sym.section 1]) \
  No invalid memory access

  #light([#sym.section 2]) \
  No mutable reference aliasing
][]

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

  - #light([Either]) one mutable _live_ reference \ #light([or]) multiple (shared) immutable reference

    #let c = ```rust
        let mut counter = 0;
        let ref1 = &mut counter;
        // ...
        let ref2 = &mut counter; //  <- Error
        use(ref1)
    ```
    #only(2)[#code((1,2,3,4,5), c)]
    #only(3)[#code((5,), c)]
  
  - No modification of borrowed data
]

#slide[
  = Checking Functions

  #let v = ```rust
  struct Vec<&'a i32> { ... }

  impl<'a> Vec<&'a i32> {
    fn push<'b>
       where 'b: 'a (&mut self, x: &'b i32) {
      // ...
    }
  }
  ```
  
  #only(1)[#code((1,2,3,4,5,6), v)]
  #only(2)[#code((3,4), v)]
  #only(3)[#code((5,), v)]

    #notes(
    ```md
    OK, so checking those rules locally (in a single function) is quite easy, but checking the whole program would be extremly expensive. It would also require the borrow checker to see the whole program, so no linking.
    
    Therefore the Rust people had to come with a clever trick. Most of the properties are local by nature. If you pass a mutable reference to a function, it must have been unique in the caller, otherwise the caller would locally violate the rules. The only rule we need to check across function boundaries is subset of lifetimes (validity periods of references).

    So, on the function boundary, programmer is required to describe the invariants of lifetimes manually. Each reference can be ascribed with a inference variable, written with apostroph at the beginning and we can relate those references using a subset relation.

    Lets see an example. We have a function magic, which takes a reference to an integer and returns some reference to an integer. From this signature, we cannot assume anything about the relation between the input and output reference.

    It could be an identity function. It could return a reference to a temporary value. Fortunatelly, we can detect this locally, so we can ignore this case.

    It could also return a reference to a global variable.

    Or randomly return a reference to a global variable or the input reference.

    Or more realistically choose between the input references. There is no way of knowing without looking at the implementation.

    So lets take a more realistic code and add some lifetime annotation. We have a Vector that stores references to integers. We require that lifetimes of the references are bound by some lifetime `'a`. We also have a push method, which takes a reference to an integer and a lifetime `'b` and we require that `'b` is a subset of `'a`. This is a way of saying that the reference must be valid at least as long as `'a`. We don't mind if it is valid longer.

    Now, in many cases you could just write `'a` everywhere and the compiler would coerce the lifetimes at call site. But there are some cases with mutable references and variance, where we need to be more careful.
    ```
  )
]

#slide[
  = Propagating lifetimes

  #only(1, ```rust
    fn max_ref(a: &i32, b: &i32) -> &i32 {
      let mut max = a;
      if (*max < *b) {
        max = b;
      }
      max
    }
  ```)
  #only(2, code((1,2),```rust
    fn max_ref(a: &'a i32, b: &'a i32) 
      -> &'a i32 {
      let mut max = a;
      if (*max < *b) {
        max = b;
      }
      max
    }
  ```))
  #only(3, code((1,2),```rust
    fn max_ref(a: &'a i32, b: &'b i32)
      -> &'c i32 {
      let mut max = a;
      if (*max < *b) {
        max = b;
      }
      max
    }
  ```))
  #only(4, code((3,),```rust
    fn max_ref(a: &'a i32, b: &'b i32)
      -> &'c i32 {
      let mut max: &i32 = a;
      if (*max < *b) {
        max = b;
      }
      max
    }
  ```))
  #only(5, {
    code((3,4,5,5,6,7),```rust
    fn max_ref(a: &'a i32, b: &'b i32)
      -> &'c i32 {
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

#section[
  = Borrow checker evolution

  Lexical, NLL, Polonius
]

#slide-big[
  == Lexical borrow checker
][
    lifetime = lexical scope#imp("*")
][]

#slide[
  == Lexical borrow checker

  #set text(size: 1em)

  #let c1 = ```rust
      fn foo() {
        let mut data = vec!['a', 'b', 'c'];
        capitalize(&mut data[..]);         
        data.push('d');
        data.push('e');
        data.push('f');
      }
  
      fn capitalize(data: &mut [char]) {
        // do something
      }
    ```
  #only(1)[#code((1,2,3,4,5,6,7,8,9,10,11,12), c1)]
  #only(2)[#code((2,), c1)]
  #only(3)[#code((3,9,10,11), c1)]
  #only(4)[#code((4,5,6,), c1)]
  
  #only(5)[
      ```rust
        fn foo() {
            let mut data = vec!['a', 'b', 'c']; // --+
            capitalize(&mut data[..]);          //   |
        //  ^~~~~~~~~~~~~~~~~~~~~~~~~ 'lifetime //   |
            data.push('d');                     //   |
            data.push('e');                     //   |
            data.push('f');                     //   |
        } // <---------------------------------------+
  
        fn capitalize(data: &mut [char]) {
            // do something
        }
      ```
  ]

  #only(6)[
      ```rust
        fn bar() {
            let mut data = vec!['a', 'b', 'c'];
            let slice = &mut data[..]; // <-+ 'lifetime
            capitalize(slice);         //   |
            data.push('d'); // ERROR!  //   |
            data.push('e'); // ERROR!  //   |
            data.push('f'); // ERROR!  //   |
        } // <------------------------------+
      ```
  ]

  #only(7)[
      ```rust
        fn bar() {
            let mut data = vec!['a', 'b', 'c'];
            {
                let slice = &mut data[..]; // <-+ 
                capitalize(slice);         //   |
            } // <------------------------------+
            data.push('d'); // OK
            data.push('e'); // OK
            data.push('f'); // OK
        }
      ```
  ]

]

#slide[
  == Lexical borrow checker

  #set text(size: .9em)

  #let c = ```rust
    fn process_or_default<K,V:Default>(
      map: &mut HashMap<K,V>,
      key: K
    ) {
        match map.get_mut(&key) { // -------------+
            Some(value) => process(value),     // |
            None => {                          // |
                map.insert(key, V::default()); // |
                //  ^~~~~~ ERROR.              // |
            }                                  // |
        } // <------------------------------------+
    }
  ```

  #only(1)[#code((1,2,3,4,5,6,7,8,9,10,11,12), c)]

  #only(2)[#code((7,8,9), c)]
]

#slide-big[
  == Non-lexical lifetimes (NLL)
][
    lifetime = set of CFG nodes
][]

#slide[
  == Non-lexical lifetimes (NLL)

  #set text(size: 1em)

  #grid(columns: (5.5fr, 2fr), column-gutter: -100pt)[
    #let c = ```rust
    fn process_or_default<K,V>(
      map: &mut HashMap<K,V>,
      key: K
    ) {
        match map.get_mut(&key) {
            Some(value) => {
              process(value);
            },     
            None => {                          
              map.insert(key, ...);
            }                                  
        }
    }
    ```

    #only(1)[#code((1,2,3,4,5,6,7,8,9,10,11,12,12), c)]
    #only(2)[#code((2,5), c)]
    #only(3)[#code((6,7,8), c)]
    #only(4)[#code((9,10,11), c)]
  ][
    #set text(size: 0.9em, font: "Roboto Mono")
    
    #only("1-2")[
    #fletcher.diagram(
      {
      let (start, match, s, n, end, ret) = ((0,0), (0,-0.75), (-0.5, -1.5), (0.5, -1.5), (0, -2.25), (0, -3))
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
    #only("3-")[
    #fletcher.diagram(
      {
      let (start, match, s, n, end, ret) = ((0,0), (0,-0.75), (-0.5, -1.5), (0.5, -1.5), (0, -2.25), (0, -3))
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

  #notes(
    ```md
    So we have out example again and on the right side we also have a very simple control flow graph. There is the start of the function, the match statement, the two branches of the match statement, end of the match statement and the end of the function.

    In the match node we call into the hashmap.
    ```
  )
]

#slide[
  == Breaking NLL
  
  #grid(columns: (3fr, 1fr), column-gutter: -100pt)[
    #let c = ```rust
    fn get_default<'m,K,V>(
      map: &'m mut HashMap<K,V>,
      key: K
    ) -> &'m mut V {
        match map.get_mut(&key) {
            Some(value) => 
              value,
            None => {            
                map.insert(key, ...);
                map.get_mut(&key)
            }                    
        }                        
    }  
    ```

    #only(1, code((1,2,3,4,5,6,7,8,9,10,11,12,13), c))
    #only(2, code((4,10), c))
    #only(3, code((5,), c))
    #only(4, code((5,6,7), c))
    #only(5, code((5,6,7,12,13), c))
    #only(6, code((5,6,7,8,9,10,11,12,13), c))
    #only(7, code((8,9,10,11), c))
  ][
    #set text(size: .9em, font: "Roboto Mono")

    #let cfg(step) = {
      fletcher.diagram(
      {
      let (start, match, s, n, end, ret) = ((0,0), (0,-0.75), (-0.5, -1.5), (0.5, -1.5), (0, -2.25), (0, -3))
      node(start, text(fill: if step >= 5 { red } else { black }, "Start"))
      node(match, text(fill: if step >= 2 { blue } else { black }, "Match"))
      node(s, text(fill: if step >= 3 { green } else { black },"Some"))
      node(n, text(fill: if step >= 5 { green } else { black },
        weight: if step >= 6 { 900 } else { 900 }
       ,"None"))
      node(end, text(fill: if step >= 4 { green } else { black}, "End"))
      node(ret, text(fill: if step >= 4 { green } else { black},"Return"))
      edge(start, match, "->")
      edge(match, s, "->")
      edge(match, n, "->")
      edge(s, end, "->")
      edge(n, end, "->")
      edge(end, ret, "->")
    })}

    #for step in range(8) {
        only(step, cfg(step - 1))
    }
  ]
]

#slide-big[
  == Polonius
][
    lifetime = set of loans
][]

#slide[
  = Polonius

    #set text(size: 1em)

    #grid(columns: (3fr, 1fr), column-gutter: -100pt)[
    #let c = ```rust
    fn get_default<'m,K,V>(
      map: &'m mut HashMap<K,V>,
      key: K
    ) -> &'m mut V {
        match map.get_mut(&key) {
            Some(value) => 
              value,
            None => {            
                map.insert(key, ...);
                map.get_mut(&key)
            }                    
        }                        
    }  
    ```

    #only(1, code((8,9,10,11), c))
  ][
    #set text(size: 0.9em,font: "Roboto Mono")

    #let cfg(step) = {
      fletcher.diagram(
      {
      let (start, match, s, n, end, ret) = ((0,0), (0,-0.75), (-0.5, -1.5), (0.5, -1.5), (0, -2.25), (0, -3))
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

#section[
  = Computing!
  Steps of the borrow checker
]

#slide[
  #only(1)[ #box(width: 100%, height: 100%, clip: true, inset: (top: 0pt), align(center, image("media/polonius.svg", height: 100%))) ]
  #only(2)[ #box(width: 100%, height: 100%, clip: true, inset: (top: 0pt), align(center, image("media/polonius.svg", height: 200%))) ]
  #only(3)[ #box(width: 100%, height: 100%, clip: true, inset: (top: -50%, bottom: 50%), align(center, image("media/polonius.svg", height: 200%))) ]
  #only(4)[ #box(width: 100%, height: 100%, clip: true, inset: (top: -100%, bottom: 100%), align(center, image("media/polonius.svg", height: 200%))) ]
  #only(5)[ #box(width: 100%, height: 100%, clip: true, inset: (top: 0pt), align(center, image("media/polonius.svg", height: 100%))) ]
]

#section[
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

  #set text(size: 1.2em)  

  ```rust
    struct Foo(i32);
  
    fn foo(x: i32) -> Foo {
        Foo(x)
    }
  ```
]

#slide[
  == MIR

    #set text(size: 1.2em)

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

  #set text(size: 1.2em)

  ```rust
    pub fn fib(n: u32) -> u32 {
      if n == 0 || n == 1 {
        1
      } else {
        fib(n-1) + fib(n - 2)
      }
    }
  ```

]

#slide[
  === MIR: Fibonacci

  #set text(size: 0.7em)

  #columns(2, gutter: 11pt)[
  ```rust
  fn fib(_1: u32) -> u32 {
    bb0: {
      StorageLive(_2);
      StorageLive(_3);
      _3 = _1;
      _2 = Eq(move _3, const 0_u32);
      switchInt(move _2) ->
        [0: bb2, otherwise: bb1];
    }
    bb2: {
      StorageDead(_3);
      StorageLive(_4);
      StorageLive(_5);
      _5 = _1;
      _4 = Eq(move _5, const 1_u32);
      switchInt(move _4) ->
        [0: bb4, otherwise: bb3];
    }
    bb7: {
      _11 = move (_13.0: u32);
      StorageDead(_12);
      _10 = fib(move _11) ->
        [return: bb8, unwind: bb11];
    }
    bb8: {
      StorageDead(_11);
      _14 = CheckedAdd(_6, _10);
      assert(!move (_14.1: bool)) ->
        [success: bb9, unwind: bb11];
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
  ```]
]

#slide[
  = Rust GCC

  #set align(center+top)
  #image("media/pipeline.svg", height: 80%)
]

#slide[
  = Rust GCC

  #set align(center+horizon)
  #image("media/bir.svg")
]

#slide[
  == BIR: Borrow Checker IR

  #set text(size: 1em)

  - basic block list
    - basic block
  - place database
  - arguments
  - return type
  - universal lifetimes
  - universal lifetime constraints
]

#slide[
  == BIR: Borrow Checker IR

  #set text(size: 1em)
  
  - `Statement`
    - `Assignment`
      - `InitializerExpr`
      - `Operator<ARITY>`
      - `BorrowExpr`
      - `AssignmentExpr (copy)`
      - `CallExpr`
    - `Switch`, 
    - `Goto`
    - `Return`
    - `StorageLive`, `StorageDead` 
    - `UserTypeAsscription`
]

#slide[
  === BIR: Fibonacci

  #set text(size: 0.7em)

  #columns(2, gutter: 1pt)[

  ```rust
  fn fib(_2: u32) -> u32 {
    bb0: {
      StorageLive(_3);
      StorageLive(_5);
      _5 = _2;
      StorageLive(_6);
      _6 = Operator(
        move _5, const u32);
      switchInt(move _6) ->
        [bb1, bb2];
    }
    bb2: {
      StorageLive(_8);
      _8 = _2;
      StorageLive(_9);
      _9 = Operator(
        move _8, const u32);
      _3 = move _9;
      goto -> bb3;
    }

    bb4: {
      _1 = const u32;
      goto -> bb8;
    }

    bb5: {
      StorageLive(_14);
      _14 = _2;
      StorageLive(_15);
      _15 = Operator(
        move _14, const u32);
      StorageLive(_16);
      _16 = Call(fib)(move _15) ->
        [bb6];
    }

    bb8: {
      return;
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

  #set text(size: 1.2em)

  #only("1")[
  ```rust
    let a: &?1 i32;
    let b: &?2 i32;
    /// ...
    a = b;
  ```]

  #only("2-")[
    ```rust
      let a: Foo<'a, 'b, T>;
      let b: Foo<'a, 'b, T>;
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

#section[  
  = Detected Errors
  Move, Subset and Loan Errors
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

  #set text(size: 1em)

  #only(1)[
      #set text(size: 1.2em)

    ```rust
    fn f() {
        struct A {
            i: i32,
        }
        let a = A { i: 1 };
        let b = a;
        let c = a;    
    }    
  ```]

  #only("2-")[
    #set text(size: .8em)

      ```rust
    fn f() {
        struct A { i: i32 }
        let a = A { i: 1 };
        let b = a;
        let c = a;    
    }    
  ```]

  #only(2)[
    ```
      example_2.rs:2:1: error: Found move errors in function f 
        2 | fn f() {
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

  #set text(size: 1em)

  #only(1)[
      #set text(size: 1.2em)

  ```rust
    fn f() {
      let mut x = 0;
      let y = &mut x;                    
      let z = &x;                         
      let w = y;                        
    }
  ```]

  #only("2-")[
    #set text(size: .8em)

    ```rust
    fn f() {
      let mut x = 0;
      let y = &mut x;                    
      let z = &x;                         
      let w = y;                        
    }
  ```]

  #only(2)[
    ```
      example_1.rs:2:1: error:
        Found loan errors in function f

      2 | fn f() {
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

  #set text(size: 1em)

  #only(1)[```rust
    fn f<'a, 'b>(
      b: bool, x: &'a u32, y: &'b u32
    ) -> &'a u32 {
        if b {
          y
        } else {
          x
        }    
    }
  ```]

  #only("2-")[```rust
    fn f<'a, 'b>(b, x: &'a, y: &'b) -> &'a {
        if b { y } else { x }    
    }
  ```]

  #only(2)[
    ```
      example_3.rs:2:1: error:
        Found subset errors in function f.
        Some lifetime constraints need to be added.

        2 | fn f<'a, 'b>(...) -> &'a u32 {
          | ^~
    ```]

  #only(3)[
    ```
      example_3.rs:2:1: error: subset error,
      some lifetime constraints need to be added
          2 | fn f<'a, 'b>(...) -> &'a u32 {
            | ^~   ~~  ~~
            | |    |   |
            | |    |   lifetime defined here
            | |    lifetime defined here
            | subset error occurs in this function
    ```]
]

#title-slide[
  = Conclusion

  Polonius trouble, Future work
]

#slide[
  = Polonius Engine Deprecated

  - Problems with over-materialization
  - Rust Edition 2024
    - Polonius Algorithm
    - NLL Infrastructure
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

  #set text(size: 0.7em, weight: "regular")

  - DUPAK, Jakub. Memory Safety Analysis in Rust GCC. Available from: _#link("https://dspace.cvut.cz/bitstream/handle/10467/113390/F3-DP-2024-Dupak-Jakub-thesis.pdf")_
  - PAL, Kushal. Google Summer of Code 2024 : Final report. Available from https://github.com/braw-lee/gsoc-2024/blob/main/README.md
  - MATSAKIS, Niko. Non lexical lifetimes introduction. Available from: _#link("https://smallcultfollowing.com/babysteps/blog/2016/04/27/non-lexical-lifetimes-introduction/")_
  - MATSAKIS, Niko. 2094-nll. In : The Rust RFC Book. Online. Rust Foundation, 2017. Available from _#link("https: rust-lang.github.io/rfcs/2094-nll.html")_
  - STJERNA, Amanda. Modelling Rust’s Reference Ownership Analysis Declaratively in Datalog. Online. Master’s thesis. Uppsala University, 2020. Available from: _#link("https://www.diva-portal.org/smash/get/diva2:1684081/fulltext01.pdf")_
  - MATSAKIS, Niko, RAKIC, Rémy and OTHERS. The Polonius Book. 2021. Rust Foundation.
  - GJENGSET, Jon.  Crust of Rust: Subtyping and Variance. 2022. Available from _#link("https://www.youtube.com/watch?v=iVYWDIW71jk")_
  - Rust Compiler Development Guide. Online. Rust Foundation, 2023. Available from _#link("https://rustc-dev-guide.rust-lang.org/index.html")_
  - TOLVA, Karen Rustad. Original Ferris.svg. Available from _#link("https://en.wikipedia.org/wiki/File:Original_Ferris.svg")_

  #light("This work is licensed under CC BY 4.0.") \
  #light([Sources are available at _#link("https://github.com/jdupak/slides-gnu-cauldron-2024-borrowing-polonius")_])
]