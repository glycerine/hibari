XDIST?=dev
VSN?=$(shell grep '{rel, "hibari"' rel/reltool.config | sed 's/^.*rel, "hibari", "\(.*\)",/\1/')
ARCH=$(shell erl -noshell -eval 'io:format(erlang:system_info(system_architecture)), halt().')
WORDSIZE=$(shell erl -noshell -eval 'io:format(integer_to_list(try erlang:system_info({wordsize, external}) of Val -> 8*Val catch error:badarg -> 8*erlang:system_info(wordsize) end)), halt().')

RELPKG=hibari-$(VSN)-$(XDIST)-$(ARCH)-$(WORDSIZE)
RELTGZ=$(RELPKG).tgz
RELMD5=hibari-$(VSN)-$(XDIST)-$(ARCH)-$(WORDSIZE)-md5sum.txt

OTPREL=$(shell erl -noshell -eval 'io:format(erlang:system_info(otp_release)), halt().')
PLT=$(HOME)/.dialyzer_plt.$(OTPREL)

DIALYZE_IGNORE_WARN?=dialyze-ignore-warnings.txt
DIALYZE_NOSPEC_IGNORE_WARN?=dialyze-nospec-ignore-warnings.txt

.PHONY: all test bootstrap-package check-package package generate compile eunit build-plt check-plt dialyze dialyze-spec dialyze-nospec dialyze-eunit dialyze-eunit-spec dialyze-eunit-nospec ctags etags clean realclean distclean

all: compile

test: eunit

bootstrap-package: package
	@echo "bootstrapping package: $(RELPKG) ..."
	@-./tmp/hibari/bin/hibari stop &> /dev/null
	@rm -rf ./tmp
	@mkdir ./tmp
	tar -C ./tmp -xzf ../$(RELTGZ)
	./tmp/hibari/bin/hibari start
	@sleep 5
	./tmp/hibari/bin/hibari-admin bootstrap
	@sleep 1

check-package: bootstrap-package
	@echo "checking package: $(RELPKG) ..."
	./tmp/hibari/bin/hibari-admin client-add hibari@127.0.0.1
	@sleep 1
	./tmp/hibari/bin/hibari-admin client-list
	./tmp/hibari/bin/hibari-admin client-delete hibari@127.0.0.1
	./tmp/hibari/bin/hibari checkpoint
	./tmp/hibari/bin/hibari stop

package: generate
	@echo "packaging: $(RELPKG) ..."
	@rm -f ../$(RELTGZ) ../$(RELMD5)
	@tar -C ./rel -czf ../$(RELTGZ) hibari
	@(cd .. && (md5sum $(RELTGZ) 2> /dev/null || md5 -r $(RELTGZ) 2> /dev/null) | tee $(RELMD5))
	@(cd .. && ls -l $(RELTGZ) $(RELMD5))

generate: clean compile
	@echo "generating: $(RELPKG) ..."
	@find ./lib -name svn -type l | xargs rm -f
	@find ./lib -name rr-cache -type l | xargs rm -f
	./rebar generate
	@perl -i -pe 's/%% (.* generated) at .*//g;' rel/hibari/releases/*/*.{rel,script}

compile:
	@echo "compiling: $(RELPKG) ..."
	./rebar compile

eunit: compile
	@echo "eunit testing: $(RELPKG) ..."
	./rebar eunit

build-plt: $(PLT)

check-plt: $(PLT)
	dialyzer --plt $(PLT) --check_plt

dialyze: dialyze-spec

dialyze-spec: build-plt clean compile
	@echo "dialyzing w/spec: $(RELPKG) ..."
	find ./lib -wholename "*/meck/test/cover_test_module.beam" -exec rm {} \;
	dialyzer --plt $(PLT) -Wunmatched_returns -r ./lib | fgrep -v -f $(DIALYZE_IGNORE_WARN)

dialyze-nospec: build-plt clean compile
	@echo "dialyzing w/o spec: $(RELPKG) ..."
	find ./lib -wholename "*/meck/test/cover_test_module.beam" -exec rm {} \;
	dialyzer --plt $(PLT) --no_spec -r ./lib | fgrep -v -f $(DIALYZE_NOSPEC_IGNORE_WARN)

dialyze-eunit: dialyze-eunit-spec

dialyze-eunit-spec: build-plt clean compile
	@echo "dialyzing .eunit w/spec: $(RELPKG) ..."
	./rebar eunit-compile
	#TODO dialyzer --plt $(PLT) -Wunmatched_returns -r `find ./lib -name .eunit -print | xargs echo` | fgrep -v -f $(DIALYZE_IGNORE_WARN)
	dialyzer --plt $(PLT) -r `find ./lib -name .eunit -print | xargs echo` | fgrep -v -f $(DIALYZE_IGNORE_WARN)

dialyze-eunit-nospec: build-plt clean compile
	@echo "dialyzing .eunit w/o spec: $(RELPKG) ..."
	./rebar eunit-compile
	dialyzer --plt $(PLT) --no_spec -r `find ./lib -name .eunit -print | xargs echo` | fgrep -v -f $(DIALYZE_NOSPEC_IGNORE_WARN)

ctags:
	find ./lib -name "*.[he]rl" -print | fgrep -v .eunit | ctags -
	find ./lib -name "*.app.src" -print | fgrep -v .eunit | ctags -a -
	find ./lib -name "*.config" -print | fgrep -v .eunit | ctags -a -
	find ./lib -name "*.[ch]" -print | fgrep -v .eunit | ctags -a -

etags:
	find ./lib -name "*.[he]rl" -print | fgrep -v .eunit | etags -
	find ./lib -name "*.app.src" -print | fgrep -v .eunit | etags -a -
	find ./lib -name "*.config" -print | fgrep -v .eunit | etags -a -
	find ./lib -name "*.[ch]" -print | fgrep -v .eunit | etags -a -

clean:
	@echo "cleaning: $(RELPKG) ..."
	./rebar clean

realclean: clean
	@echo "realcleaning: $(RELPKG) ..."
	rm -f $(PLT) TAGS

distclean:
	@echo "distcleaning: $(RELPKG) ..."
	repo forall -v -c 'git clean -fdx --exclude=lib/'

$(PLT):
	@echo "building: $(PLT) ..."
	dialyzer --build_plt --output_plt $(PLT) --apps \
		asn1 \
		compiler \
		crypto \
		dialyzer \
		edoc \
		erts \
		et \
		eunit \
		gs \
		hipe \
		inets \
		kernel \
		mnesia \
		observer \
		parsetools \
		public_key \
		runtime_tools \
		sasl \
		ssl \
		stdlib \
		syntax_tools \
		tools \
		webtool \
		xmerl
