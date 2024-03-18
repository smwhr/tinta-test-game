.PHONY: clean
.PHONY: build
.PHONY: run
.PHONY: copy

SDK = $(shell egrep '^\s*SDKRoot' ~/.Playdate/config | head -n 1 | cut -c9-)
SDKBIN=$(SDK)/bin
GAME=danger
SIM=Playdate Simulator

build: clean compile run

run: open

clean:
	rm -rf 'build/$(GAME).pdx'

compile:
	mkdir build ; "$(SDKBIN)/pdc" 'source' './build/$(GAME).pdx'

open: compile
	open -a '$(SDKBIN)/$(SIM).app/Contents/MacOS/$(SIM)' './build/$(GAME).pdx'