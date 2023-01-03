# ------------------------------------------------------------------------------

# The name of the library.
THIS     := stores

# The version number is automatically set to the current date,
# unless DATE is defined on the command line.
DATE     := $(shell /bin/date +%Y%m%d)

# The repository URL (https).
REPO     := https://github.com.fr/fpottier/$(THIS)

# The archive URL (https).
ARCHIVE  := $(REPO)/archive/$(DATE).tar.gz

# ------------------------------------------------------------------------------

.PHONY: all
all:
	dune build

.PHONY: clean
clean:
	git clean -fX

.PHONY: install
install: all
	dune install -p $(THIS)

.PHONY: uninstall
uninstall:
	dune build @install
	dune uninstall -p $(THIS)

.PHONY: reinstall
reinstall: uninstall
	@ make install

.PHONY: show
show: reinstall
	@ echo "#require \"stores\";;\n#show stores;;" | ocaml

.PHONY: pin
pin:
	opam pin add $(THIS) .

.PHONY: unpin
unpin:
	opam pin remove $(THIS)

.PHONY: test
test:
	@ make -C test $@

# A benchmark.
# Ref, Map, and Vector do not support transactions, which is why the
# loops below are structured in a strange way.
.PHONY: bench
bench:
	@ dune build bench/bench.exe
	@ for BENCH in Raw ; do \
          for IMPL in Ref TransactionalRef Map Vector ; do \
	  echo "BENCH=$$BENCH IMPL=$$IMPL" ; \
	  BENCH=$$BENCH IMPL=$$IMPL \
	  NCREATE=10 NREAD=20 NWRITE=15 ROUNDS=100 \
	  time _build/default/bench/bench.exe || true ; \
	  done ; \
	  done
	@ for BENCH in Transactional-raw Transactional-full ; do \
          for IMPL in TransactionalRef ; do \
	  echo "BENCH=$$BENCH IMPL=$$IMPL" ; \
	  BENCH=$$BENCH IMPL=$$IMPL \
	  NCREATE=10 NREAD=20 NWRITE=15 ROUNDS=100 \
	  time _build/default/bench/bench.exe || true ; \
	  done ; \
	  done

# ------------------------------------------------------------------------------

# [make versions] compiles the code under many versions of OCaml, whose
# list is specified below.

# This requires appropriate opam switches to exist. A missing switch
# can be created like this:
#   opam switch create 4.03.0

VERSIONS := \
  4.08.1 \
  4.09.1 \
  4.09.0+bytecode-only \
  4.10.0 \
  4.11.1 \
  4.12.0 \
  4.13.1 \
  4.14.1 \
  5.0.0 \

.PHONY: versions
versions:
	@(echo "(lang dune 2.0)" && \
	  for v in $(VERSIONS) ; do \
	    echo "(context (opam (switch $$v)))" ; \
	  done) > dune-workspace.versions
	@ dune build --workspace dune-workspace.versions -p $(THIS)

# ------------------------------------------------------------------------------

# Documentation.

DOCDIR = _build/default/_doc/_html
DOC    = $(DOCDIR)/index.html

.PHONY: doc
doc:
	@ rm -rf _build/default/_doc
	@ dune clean
	@ dune build @doc
	@ echo "You can view the documentation by typing 'make view'".

.PHONY: view
view: doc
	@ echo Attempting to open $(DOC)...
	@ if command -v firefox > /dev/null ; then \
	  firefox $(DOC) ; \
	else \
	  open -a /Applications/Firefox.app/ $(DOC) ; \
	fi

.PHONY: export
export: doc
	ssh yquem.inria.fr rm -rf public_html/$(THIS)/doc
	scp -r $(DOCDIR) yquem.inria.fr:public_html/$(THIS)/doc

# ------------------------------------------------------------------------------

# Headers.

HEADACHE := headache
LIBHEAD  := $(shell pwd)/headers/library-header
FIND     := $(shell if command -v gfind >/dev/null ; then echo gfind ; else echo find ; fi)

.PHONY: headache
headache:
	@ $(FIND) src -regex ".*\.ml\(i\|y\|l\)?" \
	    -exec $(HEADACHE) -h $(LIBHEAD) "{}" ";"

# ------------------------------------------------------------------------------

# Releases.

.PHONY: release
release:
# Make sure the current version can be compiled and installed.
	@ make uninstall
	@ make clean
	@ make install
# Check the current package description.
	@ opam lint
# Check if everything has been committed.
	@ if [ -n "$$(git status --porcelain)" ] ; then \
	    echo "Error: there remain uncommitted changes." ; \
	    git status ; \
	    exit 1 ; \
	  else \
	    echo "Now making a release..." ; \
	  fi
# Create a git tag.
	@ git tag -a $(DATE) -m "Release $(DATE)."
# Upload. (This automatically makes a .tar.gz archive available on gitlab.)
	@ git push
	@ git push --tags
# Done.
	@ echo "Done."
	@ echo "If happy, please type:"
	@ echo "  \"make publish\"   to publish a new opam package"
	@ echo "  \"make export\"    to upload the documentation to yquem.inria.fr"

.PHONY: publish
publish:
# Publish an opam description.
	@ opam publish -v $(DATE) $(THIS) $(ARCHIVE) .

.PHONY: undo
undo:
# Undo the last release (assuming it was done on the same date).
	@ git tag -d $(DATE)
	@ git push -u origin :$(DATE)
