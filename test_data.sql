do $$
declare
    employee_id integer;
    iteration integer;
    var_measurement_id integer;
    var_batch_id integer;
    var_measurement_type_id integer;
    var_height numeric;
    var_temperature numeric;
    var_pressure numeric;
    var_wind_direction numeric;
    var_wind_speed numeric;

    measure_settings measure_settings_type;
begin

begin
truncate table employees cascade;
truncate table measurment_baths cascade;
truncate table measurment_input_params cascade;
end;

begin
insert into employees (id, name, birthday, military_rank_id) 
values
    (1, 'Воловиков Александр Сергеевич','1978-06-24', 2),
    (2, 'Иванов Иван Иванович', '1999-09-09', 1),
    (3, 'Лев Николаевич Толстой', '1828-09-28', 2);
end;

begin
    for employee_id in (select id from employees) loop
        for iterations in 1..100 loop
			-- floor(random()*(b-a+1))+a - возвращает случайные числа из диапозона [a, b]
            var_measurement_type_id := floor(random()*(2-1+1))+1;
            var_height := floor(random()*(200-0+1))+0;
            var_temperature := floor(random()*(58+58+1))-58;
            var_pressure := floor(random()*(900-500+1))+500;
            var_wind_direction := floor(random()*(59-0+1))+0;
            var_wind_speed := floor(random()*(15-0+1))+0;

            measure_settings := measure_settings_insert(var_height, var_temperature, var_pressure, var_wind_direction, var_wind_speed);

            insert into measurment_input_params (measurment_type_id, height, temperature, pressure, wind_direction, wind_speed) 
			values (var_measurement_type_id, measure_settings.height, measure_settings.temperature, measure_settings.pressure, 
			measure_settings.wind_direction, measure_settings.wind_speed) 
			returning id into var_measurement_id;

            insert into measurment_baths (emploee_id, measurment_input_param_id, started)
            values (employee_id, var_measurement_id, now()) 
			returning id into var_batch_id;
        end loop;
    end loop;
end;
end $$;