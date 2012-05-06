
SRC_DIR = src
BUILD_DIR = build
DIST_DIR = dist
DEMOS_DIR = demos
OTHER_FILES = \
	changelog.txt \
	MIT-LICENSE.txt \
	GPL-LICENSE.txt

VER = $(shell cat version.txt)
VER_SED = sed s/@VERSION/"$(VER)"/
DATE = $(shell git log -1 --pretty=format:%ad)
DATE_SED = sed s/@DATE/"$(DATE)"/

JQ = $(shell sed -ne "s/.*JQUERY[ \t]*=[ \t]*[\"']\(.*\)[\"'].*/\1/p" "$(SRC_DIR)/_loader.js")
JQUI = $(shell sed -ne "s/.*JQUERY_UI[ \t]*=[ \t]*[\"']\(.*\)[\"'].*/\1/p" "$(SRC_DIR)/_loader.js")

DEMO_FILES = $(shell cd $(DEMOS_DIR); find . -mindepth 1 -maxdepth 1 -type f)
DEMO_SUBDIRS = $(shell cd $(DEMOS_DIR); find . -mindepth 1 -maxdepth 1 -type d)
DEMO_RE = (<script[^>]*_loader\.js[^>]*><\/script>|<!--\[\[|\]\]-->)[^<]*
DEMO_SED = sed -ne '1h;1!H;$${;g;s/$(DEMO_RE)//g;p;}'

JS_SED = sed -ne "s/[ \t]*js([\"']\(.*\)[\"']).*/\1/p"
CSS_SED = sed -ne "s/[ \t]*css([\"']\(.*\)[\"']).*/\1/p"

concat_js = \
	files=$$($(JS_SED) "$(1)/_loader.js"); \
	if [ -f "$(1)/intro.js" ]; then \
		files="intro.js $$files"; \
	fi; \
	if [ -f "$(1)/outro.js" ]; then \
		files="$$files outro.js"; \
	fi; \
	old=$$PWD; \
	if ! [ X = "X$$files" ]; then \
		(cd "$(1)"; cat $$files; cd "$$old") \
			| $(VER_SED) \
			| $(DATE_SED) \
			> "$(2)" ; \
	fi
	
concat_css = \
	files=$$($(CSS_SED) "$(1)/_loader.js"); \
	if ! [ X = "X$$files" ]; then \
		old=$$PWD; \
		(cd "$(1)"; cat $$files; cd "$$old") \
			| ${VER_SED} \
			| ${DATE_SED} \
			> "$(2)"; \
	fi

FC_V_DIR = $(BUILD_DIR)/fullcalendar-$(VER)
FC_DIR = $(FC_V_DIR)/fullcalendar
FCJS = $(FC_DIR)/fullcalendar.js
FCCSS = $(FC_DIR)/fullcalendar.css
FCPCSS = $(FC_DIR)/fullcalendar.print.css
FCMJS = $(FC_DIR)/fullcalendar.min.js
JQ_DIR = $(FC_V_DIR)/jquery
DEMOS_DIR = $(FC_V_DIR)/demos
FC_ZIP = $(FC_V_DIR).zip
DIST = $(DIST_DIR)/$(shell basename $(FC_ZIP))

.PHONY: all distribute dist
all: distribute
distribute: core plugins jquery demos others

.PHONY: clean
clean: Makefile
	rm -rf $(FC_ZIP)
	rm -rf $(FC_V_DIR)
	rm -rf $(DIST_DIR)

$(FC_V_DIR): Makefile
	mkdir -p $@

$(FC_DIR):
	mkdir -p $@

$(DEMOS_DIR):
	mkdir -p $@

$(JQ_DIR):
	mkdir -p $@

$(DIST_DIR):
	mkdir -p $@

$(FCJS): $(FC_DIR)
	$(call concat_js,$(SRC_DIR),$@)

$(FCCSS): $(FC_DIR)
	$(call concat_css,$(SRC_DIR),$@)

$(FCPCSS): $(SRC_DIR)/common/print.css $(FC_DIR)
	$(VER_SED) $< | $(DATE_SED) > $@

.PHONY: core
core: $(FCJS) $(FCCSS) $(FCPCSS)

$(FCMJS): $(FCJS)
	java -jar $(BUILD_DIR)/compiler.jar --warning_level VERBOSE --jscomp_off checkTypes --externs build/externs.js --js $< > $@

.PHONY: plugins
plugins: $(FCMJS) core
	for loader in $(SRC_DIR)/*/_loader.js; do \
		dir=`dirname $$loader`; \
		name=`basename $$dir`; \
		$(call concat_js,$$dir,$(FC_DIR)/$$name.js); \
	done

$(JQ_DIR)/$(JQ): lib/$(JQ) $(JQ_DIR)
	cp $< $@

$(JQ_DIR)/$(JQUI): lib/$(JQUI) $(JQ_DIR)
	cp $< $@

.PHONY: jquery
jquery: $(JQ_DIR)/$(JQ) $(JQ_DIR)/$(JQUI)

.PHONY: demos
demos: $(FC_DIR) $(DEMOS_DIR)
	for f in $(DEMO_FILES); do \
		cat $(DEMOS_DIR)/$$f \
			| $(DEMO_SED) \
			| sed "s/jquery\.js/${JQ}/" \
			| sed "s/jquery-ui\.js/${JQUI}/" \
			> $(DEMOS_DIR)/$$f; \
	done
	for d in $(DEMO_SUBDIRS); do \
		cp -r $(DEMOS_DIR)/$$d $(DEMOS_DIR)/$$d; \
	done

.PHONY: others
others: $(FC_DIR)
	cp -r $(OTHER_FILES) $(FC_DIR)

$(FC_ZIP): $(FC_V_DIR) distribute
	zip -q -r $@ $<

$(DIST): $(FC_ZIP) $(DIST_DIR)
	mv $@ $<
