// Copyright 2023. Silvano DAL ZILIO (LAAS-CNRS). All rights reserved. Use of
// this source code is governed by the GNU Affero license that can be found in
// the LICENSE file.

package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	"github.com/dalzilio/hue/pkg/formula"
)

func main() {
	root := os.Args[1]
	fileInfo, err := os.ReadDir(root)
	if err != nil {
		log.Fatal(err)
	}
	for _, dir := range fileInfo {
		if !dir.IsDir() {
			continue
		}
		answer("ReachabilityFireability", root, dir.Name())
		answer("ReachabilityCardinality", root, dir.Name())
	}
}

func doSimplify(q formula.Query, compet string) formula.Query {
	result := make(chan formula.Query, 1)

	if compet == "ReachabilityFireability" {
		go func() {
			q.Formula, _ = formula.BddFireabilitySimplify(q.Formula)
			result <- q
		}()
	} else {
		go func() {
			q.Formula = formula.Simplify(q.Formula)
			result <- q
		}()
	}

	select {
	case <-time.After(60 * time.Second):
		return q
	case result := <-result:
		return result
	}
}

func answer(compet string, root string, dirfile string) {
	formulafile := filepath.Join(filepath.Join(root, dirfile), compet+".xml")
	xmlFile, err := os.Open(formulafile)
	if err != nil {
		log.Fatal("Error opening file:", err)
		os.Exit(1)
		return
	}
	defer xmlFile.Close()
	decoder := formula.NewDecoder(xmlFile)
	queries, err := decoder.Build()
	if err != nil {
		log.Fatal("Error decoding Formula file:", err)
		os.Exit(1)
		return
	}
	isEF := checkIfEFandSimplify(queries)
	for k, q := range queries {
		fmt.Printf("%s-%s-%02d %s %d\n", dirfile, compet, k, isEF[k], formula.Size(q.Formula))
	}
}

// checkIfEFandSimplify returns a slice of 16 strings, one for each query,
// telling us wether it is a EF or AG formula. Therefore, knowing the verdict,
// we can decide if it is a CEX or INV. For th etime being, we disable the
// simplification because it can be very time consuming (I need to better
// integrate a timeout using contexts inside the BDD library).
func checkIfEFandSimplify(queries []formula.Query) []string {
	// var triv string
	res := make([]string, len(queries))
	for k, q := range queries {
		// added a 60s timeout, for e.g. DrinkVendingMachine-PT-10

		// REMOVED: I removed, for the time being, test for trivial formulas
		// because it is very time consuming

		// q = doSimplify(q, compet)

		// if q.IsTrivial() {
		// 	rez := q.Formula.(formula.BooleanConstant)
		// 	if rez {
		// 		triv = "CSTTRUE"
		// 	} else {
		// 		triv = "CSTFALSE"
		// 	}
		// } else {
		// 	triv = "COMPLEX"
		// }
		if q.IsEF {
			res[k] = "EF"
		} else {
			res[k] = "AG"
		}
	}
	return res
}
