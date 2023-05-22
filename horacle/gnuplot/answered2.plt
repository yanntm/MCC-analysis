set output './answered2.png'
set tics scale 0
set xzeroaxis
set xtics rotate by 75 right
plot './answered2.dat' using 0:2:xticlabel(1) with lines title '' linetype 4 lw 6