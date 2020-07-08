#! /bin/bash

tbl_agency='CREATE TABLE agency (
	agency_id TEXT UNIQUE
	agency_name TEXT NOT NULL
	agency_url TEXT NOT NULL
	agency_timezone TEXT NOT NULL
	agency_lang TEXT
	agency_phone TEXT
	agency_fare_url TEXT
	agency_email TEXT
);';

tbl_routes='CREATE TABLE routes (
	route_id TEXT PRIMARY KEY
	agency_id TEXT NOT NULL
	route_short_name TEXT
	route_long_name TEXT NOT NULL
	route_desc TEXT
	route_type INTEGER
	route_color TEXT
	route_text_color TEXT
	
	FOREIGN KEY (agency_id) 	REFERENCES agency (agency_id)			ON DELETE NO ACTION ON UPDATE NO ACTION
);';

tbl_trips='CREATE TABLE trips (
	route_id TEXT NOT NULL
	service_id INTEGER NOT NULL
	trip_id TEXT PRIMARY KEY
	trip_headsign TEXT
	trip_short_name TEXT
	direction_id INTEGER
	block_id INTEGER
	shape_id INTEGER
	wheelchair_accessible INTEGER
	bikes_allowed INTEGER
	
	FOREIGN KEY (route_id) 		REFERENCES routes (route_id) 			ON DELETE NO ACTION ON UPDATE NO ACTION
	FOREIGN KEY (service_id) 	REFERENCES calendar_dates (service_id) 	ON DELETE NO ACTION ON UPDATE NO ACTION
	FOREIGN KEY (shape_id) 		REFERENCES shapes (shape_id) 			ON DELETE NO ACTION ON UPDATE NO ACTION
	FOREIGN KEY (block_id) 		REFERENCES trips (trip_id)				ON DELETE NO ACTION ON UPDATE NO ACTION
);';

tbl_stop_times='CREATE TABLE stop_times (
	trip_id TEXT NOT NULL
	arrival_time TEXT NOT NULL
	departure_time TEXT NOT NULL
	stop_id TEXT NOT NULL
	stop_sequence INTEGER
	stop_headsign TEXT
	pickup_type INTEGER DEFAULT 0
	drop_off_type INTEGER DEFAULT 0
	timepoint INTEGER
	
	FOREIGN KEY (trip_id)		REFERENCES trips (trip_id) 				ON DELETE NO ACTION ON UPDATE NO ACTION
	FOREIGN KEY (stop_id) 		REFERENCES stops (stop_id) 				ON DELETE NO ACTION ON UPDATE NO ACTION
);';

tbl_calendar_dates='CREATE TABLE calendar_dates (
	service_id INTEGER NOT NULL
	date INTEGER NOT NULL
	exception_type INTEGER
);';

tbl_stops='CREATE TABLE stops (
	stop_id TEXT PRIMARY KEY
	stop_code TEXT
	stop_name TEXT NOT NULL
	stop_desc TEXT
	stop_lat TEXT NOT NULL
	stop_lon TEXT NOT NULL
	location_type INTEGER
	parent_station INTEGER
	wheelchair_boarding INTEGER
	platform_code TEXT
	zone_id TEXT
);';

tbl_feed_info="CREATE TABLE feed_info (
	feed_publisher_name TEXT NOT NULL
	feed_publisher_url TEXT NOT NULL
	feed_lang TEXT NOT NULL
	feed_start_date INTEGER
	feed_end_date INTEGER
	feed_version TEXT
	feed_contact_email TEXT
	feed_contact_url TEXT
);";

tbl_calendar='CREATE TABLE calendar (
	service_id INTEGER NOT NULL
	monday INTEGER NOT NULL
	tuesday INTEGER NOT NULL
	wednesday INTEGER NOT NULL
	thursday INTEGER NOT NULL
	friday INTEGER NOT NULL
	saturday INTEGER NOT NULL
	sunday INTEGER NOT NULL
	start_date TEXT NOT NULL
	end_date TEXT NOT NULL
);';

tbl_transfers='CREATE TABLE transfers (
	from_stop_id TEXT NOT NULL
	to_stop_id TEXT NOT NULL
	from_trip_id TEXT NOT NULL
	to_trip_id TEXT NOT NULL
	from_route_id TEXT NOT NULL
	to_route_id TEXT NOT NULL
	transfer_type INTEGER NOT NULL
	min_transfer_time INTEGER
	
	FOREIGN KEY (from_stop_id) 	REFERENCES stops (stop_id)			ON DELETE NO ACTION ON UPDATE NO ACTION
	FOREIGN KEY (to_stop_id) 	REFERENCES stops (stop_id)			ON DELETE NO ACTION ON UPDATE NO ACTION
	FOREIGN KEY (from_trip_id) 	REFERENCES trip (trip_id)			ON DELETE NO ACTION ON UPDATE NO ACTION
	FOREIGN KEY (to_trip_id) 	REFERENCES trip (trip_id)			ON DELETE NO ACTION ON UPDATE NO ACTION
	FOREIGN KEY (from_route_id) REFERENCES routes (route_id)		ON DELETE NO ACTION ON UPDATE NO ACTION
	FOREIGN KEY (to_route_id) 	REFERENCES routes (route_id)		ON DELETE NO ACTION ON UPDATE NO ACTION
);';

tbl_shapes='CREATE TABLE shapes (
	shape_id TEXT NOT NULL
	shape_pt_lat TEXT NOT NULL
	shape_pt_lon TEXT NOT NULL
	shape_pt_sequence INTEGER NOT NULL
	shape_dist_traveled REAL
);';

tbl_frequencies='CREATE TABLE frequencies (
	trip_id TEXT NOT NULL
	start_time TEXT NOT NULL
	end_time NOT NULL
	headway_secs REAL NOT NULL
	exact_times INTEGER
	
	FOREIGN KEY (trip_id) 	REFERENCES trip (trip_id)				ON DELETE NO ACTION ON UPDATE NO ACTION
);';

idx_all='CREATE UNIQUE INDEX idx_agency_id 	ON agency (agency_id);
	CREATE INDEX idx_route_long_name 		ON routes (route_long_name);
	CREATE INDEX idx_departure_time 		ON stop_times (departure_time);
	CREATE INDEX idx_arrival_time 			ON stop_times (arrival_time);
	CREATE INDEX idx_service_id_caldate 	ON calendar_dates (service_id);
	CREATE INDEX idx_date 					ON calendar_dates (date);
	CREATE INDEX idx_stop_name 				ON stops (stop_name);
	CREATE INDEX idx_service_id_cal 		ON calendar (service_id);
	CREATE UNIQUE INDEX idx_shape_id 		ON shapes (shape_id, shape_pt_sequence);';


rm -f db.sqlite3;

gtfs_files="feed_info agency routes fare_rules fare_attributes stop_times stops trips transfers frequencies calendar_dates shapes calendar";

for file in $gtfs_files; do
	if [ ! -f ./$file.txt ]; then
    	continue;
	fi	
	
	sed 's/\r//g' $file.txt > /tmp/$file.txt;
	
	header=$(head -n 1 "/tmp/$file.txt" | sed 's/\"//g');
	echo $file;
	
	data_sql=tbl_$file;
	sql=$(echo "${!data_sql}" | grep "CREATE");
	f_sql="";
	for c_header in ${header//,/ }; do
		tmp2=$(echo "${!data_sql}" | grep -w "$c_header" | grep -v "FOREIGN");
		tmp=$(echo "${!data_sql}" | grep "KEY ($c_header)");
		sql="$sql
		$tmp2,";
		
		if [[ ! -z $tmp ]]; then
			f_sql="$f_sql
			$tmp,";
		fi;
	done;
	if [[ ! -z $f_sql ]]; then
		sql="$sql
		$f_sql";
	fi;
	tmp3=$(echo "$idx_all" | grep -w "$file" | grep -w "${header//,/\\|}");
	sql="${sql::-1});
	$tmp3";
	
	echo "$sql" | sqlite3 db.sqlite3;
	
	tail -n +2 /tmp/$file.txt > /tmp/sqlite.tmp;
	printf ".mode csv \n.separator \",\" \n.import /tmp/sqlite.tmp $file\n" | sqlite3 db.sqlite3;
	
	rm -f /tmp/sqlite.tmp;
	rm -f /tmp/$file.txt;
done;
