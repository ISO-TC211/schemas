SHELL := /bin/bash
XSDSRC := $(shell yq e .source.schemas schemas.yml | cut -c 3-)
XSDDOC := $(patsubst %.xsd,_site/%/index.html,$(XSDSRC))

XSDVIPATH := ${CURDIR}/xsdvi/xsdvi.jar
XSLT_FILE := ${CURDIR}/xsl/xs3p.xsl
XSLT_FILE_MERGE := ${CURDIR}/xsl/xsdmerge.xsl

all: _xsddoc

clean:
	rm -rf $(XSDDOC)

_xsddoc: $(XSDDOC)

xsdvi/xsdvi.zip:
	mkdir -p $(dir $@)
	curl -sSL https://sourceforge.net/projects/xsdvi/files/latest/download > $@

$(XSDVIPATH): xsdvi/xercesImpl.jar
	curl -sSL https://github.com/metanorma/xsdvi/releases/download/v1.0/xsdvi-1.0.jar > $@

$(XSLT_FILE):
	mkdir -p $(dir $@)
	curl -sSL https://raw.githubusercontent.com/unitsml/schemas/master/xsl/xs3p.xsl > $@

$(XSLT_FILE_MERGE):
	mkdir -p $(dir $@)
	curl -sSL https://raw.githubusercontent.com/unitsml/schemas/master/xsl/xsdmerge.xsl > $@

xsdvi/xercesImpl.jar: xsdvi/xsdvi.zip
	unzip -p $< dist/lib/xercesImpl.jar > $@

_site/%/index.html: %.xsd $(XSDVIPATH) $(XSLT_FILE) $(XSLT_FILE_MERGE)
	mkdir -p $(dir $@)diagrams; \
	java -jar $(XSDVIPATH) $(CURDIR)/$< -rootNodeName all -oneNodeOnly -outputPath $(dir $@)diagrams; \
	xsltproc --nonet --stringparam rootxsd $< \
		--output $@.tmp $(XSLT_FILE_MERGE) $<;\
	xsltproc --nonet --param title "'Schema Documentation for $(notdir $*)'" \
		--output $@ $(XSLT_FILE) $@.tmp;\
	rm $@.tmp

.PHONY: all clean
