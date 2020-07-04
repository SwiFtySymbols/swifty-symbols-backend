#!/usr/bin/env sh

psql -h localhost swiftysymbolsbe -c "drop schema public cascade; create schema public; grant all on schema public to mredig; grant all on schema public to swiftysymbolsbe; grant all on schema public to public;"
