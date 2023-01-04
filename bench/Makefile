# A benchmark.
# Ref, Map, and Vector do not support transactions, which is why the
# loops below are structured in a strange way.
.PHONY: run
run: all
	@ dune build ./bench.exe
	@ for BENCH in Raw ; do \
          for IMPL in Ref TransactionalRef Vector VectorDyn Map ; do \
	  echo "BENCH=$$BENCH IMPL=$$IMPL" ; \
	  BENCH=$$BENCH IMPL=$$IMPL \
	  NCREATE=10 NREAD=20 NWRITE=15 ROUNDS=100 \
	  time ../_build/default/bench/bench.exe || true ; \
	  done ; \
	  done
	@ for BENCH in Transactional-raw Transactional-full ; do \
          for IMPL in TransactionalRef ; do \
	  echo "BENCH=$$BENCH IMPL=$$IMPL" ; \
	  BENCH=$$BENCH IMPL=$$IMPL \
	  NCREATE=10 NREAD=20 NWRITE=15 ROUNDS=100 \
	  time ../_build/default/bench/bench.exe || true ; \
	  done ; \
	  done


.PHONY: all
all:
	@ dune build ./bench.exe
