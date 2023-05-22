package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"strings"
)

func main() {
	resultfile, err := os.Open(os.Args[1])
	if err != nil {
		log.Fatal("Error opening file:", err)
		os.Exit(1)
		return
	}
	defer resultfile.Close()
	oracleScanner := bufio.NewScanner(resultfile)

	for oracleScanner.Scan() {
		line := strings.Fields(oracleScanner.Text())
		if len(line) != 18 {
			fmt.Println(line)
			log.Fatal("line is too short")
		}
		rez := []rune(line[1])
		for i := 0; i < 16; i++ {
			switch rez[i] {
			case '?':
				fmt.Printf("%s-%02d %s %s\n", line[0], i, "UNKNOWN", line[i+2])
			case 'T':
				fmt.Printf("%s-%02d %s %s\n", line[0], i, "TRUE", line[i+2])
			case 'F':
				fmt.Printf("%s-%02d %s %s\n", line[0], i, "FALSE", line[i+2])
			case 'P':
				fmt.Printf("%s-%02d %s %s\n", line[0], i, "POSSIBLE", line[i+2])
			case 'U':
				fmt.Printf("%s-%02d %s %s\n", line[0], i, "UNLIKELY", line[i+2])
			}
		}
	}
	// fmt.Printf("%d lines parsed\n", len(oracle))
}
