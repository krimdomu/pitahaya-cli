FROM ubuntu:latest

RUN apt-get update; \
    apt-get -y install perl cpanminus carton perl-doc dos2unix git libdist-zilla-perl; \
    apt-get -y build-dep libdbix-class-perl libdata-uuid-libuuid-perl

RUN mkdir -p /pitahaya/cli
COPY bin /pitahaya/cli/bin
COPY lib /pitahaya/cli/lib
COPY dist.ini /pitahaya/cli/
COPY .perlcriticrc /pitahaya/cli/
COPY .perltidyrc /pitahaya/cli/
COPY cpanfile /pitahaya/cli/

RUN find /pitahaya -type f -exec chown 0644 '{}' ';'; \
    find /pitahaya -type f -exec dos2unix '{}' ';'; \
    chmod 0755 /pitahaya/cli/bin/*; \
    mkdir -p /pitahaya/api; \
    cd /pitahaya/api ; git clone https://github.com/krimdomu/pitahaya-client-api.git . && \
    dzil authordeps --missing | cpanm -n && \
    dzil install && \
    cd /pitahaya/cli; \
    dzil listdeps --missing | cpanm -n && \
    dzil install

ENV PATH=$PATH:/pitahaya/cli/bin
ENV PERL5LIB=$PERL5LIB:/pitahaya/cli/lib:/pitahaya/cli/local/lib/perl5:/pitahaya/api/lib

