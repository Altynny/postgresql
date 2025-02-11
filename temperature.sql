do $$

declare param interpolation_params;
declare y numeric(4,2);

begin
param.x := 22; 
select * from
(select temperature, delta from temperature where temperature <= param.x order by id desc limit 1)
left join
(select temperature, delta from temperature where temperature > param.x limit 1) on true
into param.x0, param.y0, param.x1, param.y1;

raise notice 'param %', param;
y := param.y0 + ((param.x - param.x0)*(param.y1 - param.y0)/(param.x1 - param.x0));
raise notice 'interpolate_val %', y;
raise notice 'corrected_temp %', param.x+y;

end $$;