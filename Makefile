SHELL := /bin/bash
XSDSRC := $(shell yq e .source.schemas schemas.yml | cut -c 3-)
XSDDOC := $(patsubst %.xsd,_site/%/index.html,$(XSDSRC))

XERCESURL := https://downloads.apache.org/xerces/j/binaries/Xerces-J-bin.2.12.1.tar.gz
XSDVIURL := https://github.com/metanorma/xsdvi/releases/download/v1.0/xsdvi-1.0.jar
XS3PURL := https://github.com/metanorma/xs3p/archive/refs/tags/v3.0.tar.gz

XERCESPATH := xsdvi/xercesImpl.jar
XSDVIPATH := xsdvi/xsdvi.jar
XS3PPATH := xsl/xs3p.xsl
XSDMERGEPATH := xsl/xsdmerge.xsl

all: _xsddoc

setup: $(XSDVIPATH) $(XERCESPATH) $(XS3PPATH)

.archive/Xerces-J-bin.2.12.1.tar.gz:
	mkdir -p $(dir $@)
	curl -sSL -o $@ $(XERCESURL)

.archive/xsdvi-1.0.jar:
	mkdir -p $(dir $@)
	curl -sSL -o $@ $(XSDVIURL)

.archive/xs3p.tar.gz:
	mkdir -p $(dir $@)
	curl -sSL -o $@ $(XS3PURL)

$(XSDVIPATH): .archive/xsdvi-1.0.jar
	mkdir -p $(dir $@)
	cp $< $@

$(XERCESPATH): .archive/Xerces-J-bin.2.12.1.tar.gz
	mkdir -p $(dir $@)
	tar -zxvf $< -C xsdvi --strip-components=1 xerces-2_12_1/xercesImpl.jar
	touch $@

$(XS3PPATH): .archive/xs3p.tar.gz
	mkdir -p $(dir $@)
	tar -zxvf $< -C xsl --strip-components=2 xs3p-3.0/xsl
	touch $@

$(XSDMERGEPATH): $(XS3PPATH)

_xsddoc: $(XSDDOC)

_site/%/index.html: %.xsd $(XSDVIPATH) $(XS3PPATH) $(XSDMERGEPATH)
	mkdir -p $(dir $@)diagrams; \
	java -jar $(XSDVIPATH) $(CURDIR)/$< -rootNodeName all -oneNodeOnly -outputPath $(dir $@)diagrams; \
	xsltproc --nonet --stringparam rootxsd $< \
		--output $@.tmp $(XSDMERGEPATH) $<;\
	xsltproc --nonet --param title "'Schema Documentation for $(notdir $*)'" \
		--output $@ $(XS3PPATH) $@.tmp;\
	rm $@.tmp

clean:
	rm -rf _site xsl xsdvi

distclean: clean
	rm -rf .archive

.PHONY: all clean setup distclean
