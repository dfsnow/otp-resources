#!/bin/bash


##### SETUP #####

export year="2010"
export state=$(echo "$GEOID" | cut -c 1-2)

# Set URLs and filenames for OSM, counties, and blocks
export osm_url="https://download.geofabrik.de"
export osm_file="north-america-latest.osm.pbf"
export tag_file="tag_extract.pbf"

export county_url="https://www2.census.gov/geo/tiger/TIGER"$year"/COUNTY/"$year""
export county_file="tl_"$year"_us_county10"

# Input checking for ENV variables
if [ $(echo -n "$GEOID" | wc -c) -ne 5 ]; then
    echo "Please enter a county (5 digits) for the GEOID var"
    exit 1
fi

# Create output folders if they don't exist
mkdir -p /resources/outputs/"$GEOID"
mkdir -p /resources/inputs/osm
mkdir -p /resources/inputs/buffers
mkdir -p /resources/inputs/shapefiles/counties
mkdir -p /resources/inputs/shapefiles/blocks

##### INPUTS #####

echo "Now processing county: "$GEOID""

# Get OSM North America file
if [ ! -f /resources/inputs/osm/"$osm_file" ]; then
    echo "Downloading North American OSM extract from Geofabrik..."
    wget -O /resources/inputs/osm/"$osm_file" \
         "$osm_url"/"$osm_file"
fi

# Get national county file
if [ ! -f /resources/inputs/shapefiles/counties/"$county_file".shp ]; then
    echo "Downloading national county shapefile from TIGER..."
    wget -O /resources/inputs/shapefiles/counties/"$county_file".zip \
        "$county_url"/"$county_file".zip
    unzip /resources/inputs/shapefiles/counties/"$county_file".zip \
        -d /resources/inputs/shapefiles/counties/
fi


##### OUTPUTS #####

# Create buffered counties if they don't exist
if [ ! -f /resources/inputs/buffers/"$GEOID".geojson ]; then
    python3 /resources/scripts/02_buffer_counties.py
fi

# Create OSM tag extract if it doesn't exist
if [ ! -f /resources/inputs/osm/"$tag_file" ]; then
    echo "Creating a tag filtered version of the NA OSM file..."
    osmium tags-filter /resources/inputs/osm/"$osm_file" \
        w/highway="$(cat /tmp/osm_tags.txt | tr '\n' ',')" \
        --overwrite --progress \
        -o /resources/inputs/osm/"$tag_file"
fi

# Create a clipped PBF of the buffered county
if [ ! -f /resources/outputs/"$GEOID"/"$GEOID".pbf ]; then
    echo "Creating a clipped PBF of OSM ways in the "$GEOID" buffer..."
    clipping_poly="/resources/inputs/buffers/"$GEOID".geojson"
    osmium extract -p "$clipping_poly" \
        /resources/inputs/osm/"$tag_file" \
        --overwrite --progress \
        -o /resources/outputs/"$GEOID"/"$GEOID".pbf
fi

echo "Generating origins and destinations files for "$GEOID"..."
python3 /resources/scripts/03_get_origins_destinations.py

echo "Grabbing GTFS feeds for "$GEOID"..."
python3 /resources/scripts/04_get_transit_feeds.py

echo "Finishing processing county "$GEOID""