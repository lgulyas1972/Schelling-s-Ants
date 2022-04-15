; PROGRAMMING:
; TODO: Grid: Shrink Node size according to number-of-nodes
; TODO: Implement Stochastic
;
; TODO: No hard-coded thresholds, but majority (at least for put-down), except for empty
;
; EXPERIMENT TODO: Explore density threshold (with various numbers of colors)
; TODO: Stochastics or other change, to make sure, 1-color, low-density situations are also sorted.
;
; LONG-TERM:
; TODO: IDEA: Changing threshold-in-time (increasing to freeze)

; TODO: Plot Spatial Entropy
;      https://www.rdocumentation.org/packages/SpatEntropy/versions/2.0-1/topics/SpatEntropy
;      Not very usable, needs piles, 1 color (Gutowitz): https://www.journalagent.com/itujfa/pdfs/ITUJFA-83703-THEORY_ARTICLES-EKINOGLU.pdf
;      -- MOST IMPORTANTLY, it needs a spatial grid on the net
;      Important, but not available in PDF: https://link.springer.com/article/10.1007/s10651-017-0383-1
;      Old, but base (maybe): https://onlinelibrary.wiley.com/doi/pdf/10.1111/j.1538-4632.1974.tb01014.x
;
;      In fact, what we would like to measure is the 'minimisation of cluster boundaries' (i.e., links that connect different color nodes).
;      WHAT IS THE THEORETICAL MINIMUM, in case of N nodes, M agents and K colors? Let's assume equal amounts of colors, and also same amount of empty cells.
;      Thus, food-density = number-of-colors * number-of-nodes / (number-of-colors + 1).
;      Draft calculations (approximate) for a grid topology:
;      Probably, a sub-square setup is optimal (PROOF?):
;      +--+--+
;      |  |  |
;      +--+--+
;      |  |  |
;      +--+--+
;
;      Here
;           #cells = N^2,
;           #boundary-cells = 4 * (4 * N/2) = 8N,
;           #inside-sub-squares = (N/2 - 2)^2 = N^2/4 - 2N + 4
;
;           Do basic experiments with plotting the above as a function of N.
;           Then as a percentage/ratio of N^2 (the number of nodes).
;
;      Is this optimal? A circle would minimalize the boundary of a cluster, but here we need tiling.


; TODO: Plot #hops = (tick * num-agents), #carries (#hops-while-carrying, #acts, avg-length-of-carry), #times-an-item-was-carried (would be nice, not supported by implementation)

; CONTRIBUTIONS of would-be-paper on Info TAB!!!!

breed [nodes node]
breed [workers worker]

globals [color-list carry-hops number-of-food start-modularity start-same-color-links-percentage start-avg-percent-same-color-neighbor t-to-conv start-corrected-avg-percent-same-color-neighbor ]

to setup
  clear-all

  ask patches [ set pcolor white ]

  ifelse (Topology = "Spatially Clustered") [
    setup-nodes
    setup-spatially-clustered-network
  ]
  [ ifelse (Topology = "Grid-4") [
      set number-of-nodes (int sqrt number-of-nodes) ^ 2
      setup-nodes
      setup-grid4-network
    ]
    [ ifelse (Topology = "Grid-8") [
        setup-nodes
        setup-grid8-network 1
      ]
      [ ifelse (Topology = "Random") [
        setup-nodes
        setup-random-network
        ]
        [ ifelse (Topology = "Watts-Strogatz-1D") [
          setup-nodes
          setup-1DWS-network
          ]
          [
            ifelse (Topology = "Watts-Strogatz-2D") [
              setup-nodes
              setup-2DWS-network
            ]
            [ ifelse (Topology = "Barabási-Albert") [
              setup-nodes
              setup-BA-network
              ]
              [
                print "Illegal network type selected. Using random."
                setup-nodes
                setup-random-network
              ]
            ]
          ]
        ]
      ]
    ]
  ]

  setup-workers

  set number-of-food number-of-nodes * food-density

  set color-list sublist base-colors 0 number-of-colors
  ask n-of number-of-food nodes [
    set color one-of color-list
  ]

  set carry-hops 0
  set start-modularity modularity
  set start-same-color-links-percentage (num-same-color-links) / count links
  set start-avg-percent-same-color-neighbor report-avg-percent-same-color-neighbor
  set start-corrected-avg-percent-same-color-neighbor report-avg-corrected-same-color-neighbor
  set t-to-conv -1
  reset-ticks
end


to setup-nodes
  set-default-shape nodes "circle"
  create-nodes number-of-nodes
  [
    set size 1.5
    set color black
  ]
end

to setup-random-network
  let num-links (average-node-degree * number-of-nodes) / 2

  while [count links < num-links] [
    ask one-of nodes [
      let target one-of other nodes

      if (not member? target link-neighbors) [
        create-link-with target
      ]
    ]
  ]

  ; make the network look a little prettier
  repeat 10
  [
    layout-spring nodes links 0.3 (world-width / (sqrt number-of-nodes)) 3
  ]
end

to setup-1DWS-network
  setup-ring-network param-k
  add-shortcuts
end

to setup-2DWS-network
  setup-grid8-network param-k
  add-shortcuts
end

to setup-BA-network
  if (number-of-nodes > average-node-degree) [   ; not an empty network
    ; Creating the core (of average-node-degree)
    let node-list sort nodes
    let core sublist node-list 0 (average-node-degree + 1)
    set node-list sublist node-list (average-node-degree + 1) number-of-nodes

    foreach core [ x ->
      foreach core [ y ->
        if (x != y) [
          ask y [ create-link-with x ]
        ]
      ]
    ]

    ; Creating 'average-node-degree' links for each of the not-core nodes (number-of-nodes - average-node-degree)
    foreach node-list [ x ->
      ask x [
        ; Save a copy of the current set of links. (Simple assignment is not enough as 'links' is special and allowed to grow.
        let old-links link-set links
        while [count link-neighbors < average-node-degree] [
          create-link-with [one-of both-ends] of one-of old-links
        ]
      ]
    ]

    ; make the network look a little prettier
    repeat 10
    [
      layout-radial nodes links first core
    ]
  ]
 end

to setup-spatially-clustered-network
  ask nodes [
    ; for visual reasons, we don't put any nodes *too* close to the edges
    setxy (random-xcor * 0.975) (random-ycor * 0.975)
  ]

  let num-links (average-node-degree * number-of-nodes) / 2
  while [count links < num-links ]
  [
    ask one-of nodes
    [
      let choice (min-one-of (other nodes with [not link-neighbor? myself])
                   [distance myself])
      if choice != nobody [ create-link-with choice ]
    ]
  ]

  ; make the network look a little prettier
  repeat 10
  [
    layout-spring nodes links 0.3 (world-width / (sqrt number-of-nodes)) 1
  ]
end

to setup-grid8-network [ k ]
  let min-id min [who] of nodes
  let side int sqrt number-of-nodes
  let x-padding max-pxcor / side * 2
  let y-padding max-pycor / side * 2

  ask nodes [
    let id who - min-id

    setxy ((id mod side) * x-padding + min-pxcor + 1) ((int (id / side)) * y-padding + min-pycor + 1)
    ;set label (word (id mod side) "," (int (id / side)))
  ]

  ask nodes [
    let x (who - min-id) mod side
    let y int ((who - min-id) / side)

    let mates other nodes with [
      ( (abs( (who - min-id) mod side - x ) <= k) or (abs( (who - min-id) mod side - x ) >= (side - k)) ) and
      ( (abs( int ((who - min-id) / side) - y ) <= k) or (abs( int ((who - min-id) / side) - y) >= (side - k)) )
    ]

    if mates != nobody [ create-links-with mates ]

    ; Wrap around links over the sides of the grid
;    if (x = 0) [
;      set mates other nodes with [ (int ((who - min-id) / side) = y) and ((who - min-id) mod side = (side - 1)) ]
;      if mates != nobody [ create-links-with mates ]
;    ]
;
;    if (y = 0) [
;      set mates other nodes with [ (int ((who - min-id) / side) = (side - 1)) and ((who - min-id) mod side = x) ]
;      if mates != nobody [ create-links-with mates ]
;    ]
  ]
end

to setup-grid4-network
  let min-id min [who] of nodes
  let side int sqrt number-of-nodes
  let x-padding max-pxcor / side * 2
  let y-padding max-pycor / side * 2

  ask nodes [
    let id who - min-id

    setxy ((id mod side) * x-padding + min-pxcor + 1) ((int (id / side)) * y-padding + min-pycor + 1)
    ;set label (word (id mod side) "," (int (id / side)))
  ]

  ask nodes [
    let x (who - min-id) mod side
    let y int ((who - min-id) / side)

    let mates other nodes with [
      ( (abs( (who - min-id) mod side - x ) < 1) or (abs( (who - min-id) mod side - x ) > (side - 1)) ) xor
      ( (abs( int ((who - min-id) / side) - y ) < 1) or (abs( int ((who - min-id) / side) - y) > (side - 1)) )
    ]

    if mates != nobody [ create-links-with mates ]
  ]
end

to setup-ring-network [ k ]
  ask nodes [
    let id who
    let mates other nodes with [
      (abs( who - id) <= k) or (abs(who - id) >= (number-of-nodes - k))
    ]

    if mates != nobody [ create-links-with mates ]
  ]

  layout-circle sort turtles 15
end

to add-shortcuts
  foreach (range number-of-nodes) [
    x -> foreach (remove x range number-of-nodes) [
      y -> create-stochastic-shortcut x y
    ]
  ]
end

to create-stochastic-shortcut [ x y ]
  if (link x y = nobody) and (random-float 1.0 < param-w / (number-of-nodes * number-of-nodes)) [ ask turtle x [ create-link-with turtle y] ]
end



to setup-workers
  set-default-shape workers "bug"
  create-workers number-of-workers
  [
    let n one-of nodes
    setxy [xcor] of n  [ycor] of n

    set color white
  ]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to go
  ask workers [

    let n one-of nodes-here
    let neighbor-nodes [link-neighbors] of n

    let local-color [color] of n
    let num-neighbors count neighbor-nodes

    if (color = white) and not (local-color = black) [  ; potential pick-up
      let my-color local-color ; was color
      let num-same-color count neighbor-nodes with [ color = my-color]

      ifelse (behavior = "Threshold") [
        if num-same-color < (threshold * num-neighbors) [
          set color local-color
          ask n [set color black]
        ]
      ] [
        if (random num-neighbors >= num-same-color) [
          set color local-color
          ask n[set color black]
        ]
      ]

    ]

    if not (color = white) and (local-color = black) [ ; potential put-down
      let my-color color
      let num-same-color count neighbor-nodes with [ color = my-color ]

      ifelse (behavior = "Threshold") [
        if (num-same-color >= (threshold * num-neighbors)) [
          ask n [set color my-color]
          set color white
        ]
      ] [
        if (random num-neighbors < num-same-color) [
          ask n[set color my-color]
          set color white
        ]
      ]
    ]

    ; Move to a random neighbor (if any)
    let next-node one-of neighbor-nodes
    if not (next-node = NOBODY) [
      move-to next-node
    ]
  ]

  let carrying count workers with [not (color = white)]
  set carry-hops carry-hops + carrying

  if (carrying = 0) and (t-to-conv = -1) [
    set t-to-conv ticks
  ]
  if (carrying > 1) [
    set t-to-conv -1
  ]

  tick
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Based on: https://en.wikipedia.org/wiki/Modularity_(networks)
to-report modularity
  let m count links
  let s num-same-color-links

  set s s / (2 * m)

  let k-i-square map [ x -> report-k-i-squares x m ] lput black color-list

  report (s - sum k-i-square)
end


  ; Helper reporter
  to-report report-k-i-squares [x m]
    let sum-degree sum [link-neighbors] of nodes with [color = x]
    report (sum-degree * sum-degree) / (4 * m * m)
  end

to-report num-same-color-links
  let link-ends [both-ends] of links
  let color-ends map [ x -> [color] of x] link-ends

  let s 0
  foreach color-ends [ x ->
    let f first x
    let l last x
;    if (f != black) and (l != black) and (f = l) [
    if (f = l) [
      set s (s + 1)
    ]
  ]
  report s
end

to-report report-avg-percent-same-color-neighbor
  let s 0

  ask nodes [
    let local-color color
    let num-neighbors count link-neighbors
    if (num-neighbors > 0) [
      let num-same-color count link-neighbors with [ color = local-color]
      set s s + (num-same-color / num-neighbors)
    ]
  ]

  report s / count nodes
end

to-report report-avg-corrected-same-color-neighbor
  let score report-avg-percent-same-color-neighbor
  let c count nodes

  let not-carrying count workers with [(color = white)]
  ; let carrying number-of-workers - not-carrying

  set score score * c
  ;set score score + (carrying * 0)
  set score score + not-carrying ; (not-carrying * 1)

  report score / (c + number-of-workers)
end


to-report %carry-hops
  report carry-hops / number-of-food
end

to-report D-modularity
  report modularity - start-modularity
end

to-report D-same-links
  report 100 * ((num-same-color-links / count links) - start-same-color-links-percentage)
end

to-report D-same-neighbors
  report 100 * (report-avg-percent-same-color-neighbor -  start-avg-percent-same-color-neighbor)
end

to-report D-corrected-same-neighbors
  report 100 * (report-avg-corrected-same-color-neighbor -  start-corrected-avg-percent-same-color-neighbor)
end

to-report %carrying
  report 100 * (count workers with [not (color = white)]) / number-of-workers
end

to-report %same-color-links
  report 100 * num-same-color-links / count links
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to export-nodes
  let file user-new-file

  if (is-string? file) [

    ;set file word file ".csv"

    if (count nodes > 0) [

      if (file-exists? file) [
        file-delete file
      ]

      file-open file

      let min-id min [who] of nodes
      let side int sqrt number-of-nodes

      foreach range side [
        x -> export-row side min-id x
        file-print ""
      ]

      file-close
    ]
  ]
end

to export-row [side min-id x]
  foreach range side [
    y -> ask node (y * side + x + min-id ) [file-type color file-type " "]
  ]

end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
647
448
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
11
14
74
47
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
74
14
137
47
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
137
14
200
47
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
12
58
184
91
average-node-degree
average-node-degree
1
25
8.0
1
1
NIL
HORIZONTAL

SLIDER
12
91
184
124
number-of-nodes
number-of-nodes
10
250
225.0
1
1
NIL
HORIZONTAL

SLIDER
12
276
184
309
number-of-workers
number-of-workers
1
250
25.0
1
1
NIL
HORIZONTAL

SLIDER
12
308
184
341
food-density
food-density
0
1.0
0.45
0.05
1
NIL
HORIZONTAL

SLIDER
12
341
184
374
number-of-colors
number-of-colors
1
10
2.0
1
1
NIL
HORIZONTAL

CHOOSER
12
374
183
419
behavior
behavior
"Threshold" "Stochastic"
0

SLIDER
12
456
184
489
threshold
threshold
0
1.0
0.4
0.05
1
NIL
HORIZONTAL

CHOOSER
12
124
184
169
topology
topology
"Grid-4" "Grid-8" "Spatially Clustered" "Random" "Watts-Strogatz-1D" "Watts-Strogatz-2D" "Barabási-Albert"
1

PLOT
663
12
863
162
%Carrying
NIL
NIL
0.0
1.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot %carrying"

PLOT
663
171
863
321
modularity
NIL
NIL
0.0
10.0
-0.5
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot modularity"

PLOT
663
330
863
480
%same-color-links
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot %same-color-links"

MONITOR
213
454
295
499
#carry-hops
carry-hops
0
1
11

PLOT
866
12
1066
162
avg  of %same-color-neighbor
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot 100 * report-avg-percent-same-color-neighbor"

MONITOR
298
454
384
499
%carry-hops
%carry-hops
3
1
11

MONITOR
387
454
470
499
D-modularity
D-modularity
3
1
11

MONITOR
474
454
556
499
D-same-links
D-same-links
3
1
11

MONITOR
560
454
643
499
D-same-neigh
D-same-neighbors
3
1
11

PLOT
213
503
413
653
degree-distribution
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "let max-degree max [count link-neighbors] of nodes\nplot-pen-reset  ;; erase what we plotted before\nset-plot-x-range 0 (max-degree + 1)  ;; + 1 to make room for the width of the last bar\nhistogram [count link-neighbors] of nodes\n"

SLIDER
12
168
184
201
param-k
param-k
2
4
2.0
1
1
NIL
HORIZONTAL

SLIDER
12
201
184
234
param-w
param-w
1
100
7.0
1
1
NIL
HORIZONTAL

TEXTBOX
85
218
235
236
x1/N^2\n
11
0.0
1

MONITOR
415
503
528
548
Timo-to-Converge
t-to-conv
0
1
11

PLOT
869
174
1069
324
avg-corrected-same-c-neigh
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot 100 * report-avg-corrected-same-color-neighbor"

MONITOR
531
503
647
548
D-corr-same-neigh
D-corrected-same-neighbors
17
1
11

BUTTON
12
499
118
532
NIL
export-nodes
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## CONTRIBUTIONS OF WOULD-BE-PAPER

* Link between AntSort and Segregation (minor)

* Proposal of AntSort based on local neighborhood (cf. Segregation)

* Extension of both models to networks

* Analysis of performance

	1. Comparison of the performance of the two versions (different settings, different topologies).

   	2. Introduction of indicators 
   
		* On ordering

		* On efficiency

   	3. Analysis of algorithms dependence on 

		* #Colors
		* Density of items
		* Parameters (Threshold, Memory-length, etc.)
		* Network Topology

* Proposal for Application in Edge Computing


Future Work

* Piling version -- maybe more realistic in 5G network context. Spatial entropy definitions more applicable.

## Experiment Design

We explore the Grid8 topology first.

Parameters to be explored are:

* N
* number-of-agents
* Density
* #colors
* Threshold

Output to be measured:

* #carrying (coverged or not)
* Speed of convergence
* #carry-hops
* #carry-hops-per-food-item
* Avg-of-%same-color-neighbors
* Avg-of-%same-color-links
* Modularity
* D-Avg-of-%same-color-neighbors
* D-Avg-of-%same-color-links
* D-Modularity

First, the optimal settings for **threshold** need to be set, for given *#neighbors*, as a function of **density** and **#colors**.

Then, efficiency needs to be taken into account (i.e., **#carry-hops**, **D-Modularity**, **D-avg-etc**), as a function of **#agents**.

## ON THE CHARACTERIZATION OF 'SPATIAL CLUSTERING'

In fact, what we would like to measure is the 'minimisation of cluster boundaries' (i.e., links that connect different color nodes).

**WHAT IS THE THEORETICAL MINIMUM**, in case of N nodes, M agents and K colors? 

Let's assume equal amounts of colors, and also same amount of empty cells. 

Thus, 

      food-density = number-of-colors * number-of-nodes / (number-of-colors + 1)

Draft calculations (approximate) for a grid topology follows. 
Probably, a sub-square setup is optimal (PROOF?):

      +--+--+
      |  |  |
      +--+--+
      |  |  |
      +--+--+

      Here 
           #cells = N^2, 
           #boundary-cells = 4 * (4 * N/2) = 8N, 
           #inside-sub-squares = (N/2 - 2)^2 = N^2/4 - 2N + 4

Do basic experiments with plotting the above as a function of N.
Then as a percentage/ratio of N^2 (the number of nodes).

### Is this optimal? 

A circle would minimalize the boundary of a cluster, but here we need tiling.


## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Grid8, N=225" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2000"/>
    <metric>%carrying</metric>
    <metric>t-to-conv</metric>
    <metric>carry-hops</metric>
    <metric>%carry-hops</metric>
    <metric>D-modularity</metric>
    <metric>D-same-links</metric>
    <metric>D-same-neighbors</metric>
    <metric>report-avg-percent-same-color-neighbor</metric>
    <metric>modularity</metric>
    <metric>%same-color-links</metric>
    <enumeratedValueSet variable="number-of-workers">
      <value value="10"/>
      <value value="30"/>
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="behavior">
      <value value="&quot;Threshold&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="225"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-density">
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.3"/>
      <value value="0.4"/>
      <value value="0.5"/>
      <value value="0.6"/>
      <value value="0.7"/>
      <value value="0.8"/>
      <value value="0.9"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="param-k">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-colors">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="param-w">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-node-degree">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="topology">
      <value value="&quot;Grid-8&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="threshold">
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.2"/>
      <value value="0.25"/>
      <value value="0.3"/>
      <value value="0.35"/>
      <value value="0.4"/>
      <value value="0.45"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Grid8, Good Thresholds, N=225" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2000"/>
    <metric>%carrying</metric>
    <metric>t-to-conv</metric>
    <metric>carry-hops</metric>
    <metric>%carry-hops</metric>
    <metric>D-modularity</metric>
    <metric>D-same-links</metric>
    <metric>D-same-neighbors</metric>
    <metric>report-avg-percent-same-color-neighbor</metric>
    <metric>report-avg-corrected-same-color-neighbor</metric>
    <metric>modularity</metric>
    <metric>%same-color-links</metric>
    <enumeratedValueSet variable="number-of-workers">
      <value value="10"/>
      <value value="30"/>
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="behavior">
      <value value="&quot;Threshold&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="225"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-density">
      <value value="0"/>
      <value value="0.125"/>
      <value value="0.25"/>
      <value value="0.375"/>
      <value value="0.5"/>
      <value value="0.625"/>
      <value value="0.75"/>
      <value value="0.875"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="param-k">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-colors">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="param-w">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-node-degree">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="topology">
      <value value="&quot;Grid-8&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="threshold">
      <value value="0.1"/>
      <value value="0.15"/>
      <value value="0.2"/>
      <value value="0.25"/>
      <value value="0.3"/>
      <value value="0.35"/>
      <value value="0.4"/>
      <value value="0.45"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Grid8, Good Thresholds v2, N=225" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2000"/>
    <metric>%carrying</metric>
    <metric>t-to-conv</metric>
    <metric>carry-hops</metric>
    <metric>%carry-hops</metric>
    <metric>D-modularity</metric>
    <metric>D-same-links</metric>
    <metric>D-same-neighbors</metric>
    <metric>D-corrected-same-neighbors</metric>
    <metric>report-avg-percent-same-color-neighbor</metric>
    <metric>report-avg-corrected-same-color-neighbor</metric>
    <metric>modularity</metric>
    <metric>%same-color-links</metric>
    <enumeratedValueSet variable="number-of-workers">
      <value value="10"/>
      <value value="30"/>
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="behavior">
      <value value="&quot;Threshold&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-nodes">
      <value value="225"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-density">
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.3"/>
      <value value="0.4"/>
      <value value="0.5"/>
      <value value="0.6"/>
      <value value="0.7"/>
      <value value="0.8"/>
      <value value="0.9"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="param-k">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-colors">
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="param-w">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-node-degree">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="topology">
      <value value="&quot;Grid-8&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="threshold">
      <value value="0"/>
      <value value="0.125"/>
      <value value="0.25"/>
      <value value="0.375"/>
      <value value="0.5"/>
      <value value="0.625"/>
      <value value="0.75"/>
      <value value="0.875"/>
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
