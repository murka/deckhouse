package main

import (
	"fmt"
	"log"
	"os"
	"regexp"

	goVersion "github.com/hashicorp/go-version"
	"golang.org/x/sys/unix"
)

var kernelVersionRegex = regexp.MustCompile(`^\d+\.\d+\.\d+`)

func main() {
	constraintStr := os.Args[1]

	var uname unix.Utsname
	err := unix.Uname(&uname)
	if err != nil {
		log.Fatal(err)
	}

	kernelVersionRaw := kernelVersionRegex.FindString(string(uname.Release[:]))
	if len(kernelVersionRaw) == 0 {
		log.Fatal(fmt.Errorf("failed to parse kernel release: %q", kernelVersionRaw))
	}

	kernelVersion, err := goVersion.NewVersion(kernelVersionRaw)
	if err != nil {
		log.Fatal(err)
	}

	constraint, err := goVersion.NewConstraint(constraintStr)
	if err != nil {
		log.Fatal(err)
	}

	if constraint.Check(kernelVersion) {
		os.Exit(0)
	}

	os.Exit(13)
}
