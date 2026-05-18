.PHONY: build install run test clean

build:
	./Scripts/build.sh

install: build
	./Scripts/install.sh

run:
	swift run

test:
	swift test

clean:
	rm -rf .build Overpeeped.app
