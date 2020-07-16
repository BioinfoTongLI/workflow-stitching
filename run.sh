#! /bin/sh
#
# run.sh
# Copyright (C) 2020 Tong LI <tongli.bioinfo@gmail.com>
#
# Distributed under terms of the BSD-3 license.
#


NXF_OPTS="-Dleveldb.mmap=false" nextflow -trace nextflow.executor run acapella.nf --log "$1" -with-report work/report.html ;
