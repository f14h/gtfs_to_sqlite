select sq2.line, sq2.route, agency_name, max(num_stops) from
(
	select distinct sq.headsign as headsign, sq.line as line, sq.evu as evu, group_concat(sq.stop, " - ") as route, count(sq.stop) as num_stops from
	(
		select trips.trip_id as id, trip_headsign as headsign, route_short_name as line, stop_name as stop, stop_times.stop_sequence as seq, stop_times.departure_time as times, agency_id as evu
		from stops left join stop_times on stops.stop_id = stop_times.stop_id left join trips on trips.trip_id = stop_times.trip_id join routes on trips.route_id = routes.route_id and trips.direction_id = 0
		group by stop_name, route_short_name, trips.trip_id
		order by route_short_name ASC, trips.trip_id ASC, stop_times.stop_sequence ASC
	) as sq
	group by sq.id
	order by sq.line, sq.headsign, count(sq.stop)
) as sq2
join agency on agency.agency_id = sq2.evu
group by sq2.line
order by sq2.line