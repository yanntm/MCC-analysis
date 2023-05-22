set output './density.png'
set xtics 1
set ytics 50
unset border
unset zeroaxis
set style fill transparent solid 0.2 noborder
set palette defined (0 0 0 0.5, 1 0 0 1, 2 0 0.5 1, 3 0 1 1, 4 0.5 1 0.5, 5 1 1 0, 6 1 0.5 0, 7 1 0 0, 8 0.5 0 0)
set logscale cb
plot './ff.dat' using 1:2:(sqrt(column(3)*0.01)):3 with circles fill palette title ' ' 