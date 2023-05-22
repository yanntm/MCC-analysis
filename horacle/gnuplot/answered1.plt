set output './answered1.png'
set xtics 5000
set x2tics (1015,4896,10190,28356)
set arrow from 1015, graph 0 to 1015, graph 1 nohead
set arrow from 2045, graph 0 to 2045, graph 1 nohead
plot './answered1.dat' using 1 with lines title 'answered' linetype 4 lw 6
