do $$
begin
/*
Скрипт создания информационной базы данных
Согласно технического задания https://git.hostfl.ru/VolovikovAlex/Study2025
Редакция 2025-02-12
Edit by valex
*/


/*
 1. Удаляем старые элементы
 ======================================
 */

raise notice 'Запускаем создание новой структуры базы данных meteo'; 
begin

	-- Связи
	alter table if exists public.measurment_input_params
	drop constraint if exists measurment_type_id_fk;

	alter table if exists public.employees
	drop constraint if exists military_rank_id_fk;

	alter table if exists public.measurment_baths
	drop constraint if exists measurment_input_param_id_fk;

	alter table if exists public.measurment_baths
	drop constraint if exists emploee_id_fk;

	-- Таблицы
	drop table if exists public.measurment_input_params;
	drop table if exists public.measurment_baths;
	drop table if exists public.employees;
	drop table if exists public.measurment_types;
	drop table if exists public.military_ranks;

	-- Нумераторы
	drop sequence if exists public.measurment_input_params_seq;
	drop sequence if exists public.measurment_baths_seq;
	drop sequence if exists public.employees_seq;
	drop sequence if exists public.military_ranks_seq;
	drop sequence if exists public.measurment_types_seq;

	-- Функции с зависимостями
	drop function if exists public.measure_settings_insert(numeric, numeric, numeric, numeric, numeric);
end;

raise notice 'Удаление старых данных выполнено успешно';

/*
 2. Добавляем структуры данных 
 ================================================
 */

-- Справочник должностей
create table military_ranks
(
	id integer primary key not null,
	description character varying(255)
);

insert into military_ranks(id, description)
values(1,'Рядовой'),(2,'Лейтенант');

create sequence military_ranks_seq start 3;

alter table military_ranks alter column id set default nextval('public.military_ranks_seq');

-- Пользователя
create table employees
(
    id integer primary key not null,
	name text,
	birthday timestamp ,
	military_rank_id integer
);

insert into employees(id, name, birthday,military_rank_id )  
values(1, 'Воловиков Александр Сергеевич','1978-06-24', 2);

create sequence employees_seq start 2;

alter table employees alter column id set default nextval('public.employees_seq');


-- Устройства для измерения
create table measurment_types
(
   id integer primary key not null,
   short_name  character varying(50),
   description text 
);

insert into measurment_types(id, short_name, description)
values(1, 'ДМК', 'Десантный метео комплекс'),
(2,'ВР','Ветровое ружье');

create sequence measurment_types_seq start 3;

alter table measurment_types alter column id set default nextval('public.measurment_types_seq');

-- Таблица с параметрами
create table measurment_input_params
(
    id integer primary key not null,
	measurment_type_id integer not null,
	height numeric(8,2) default 0,
	temperature numeric(8,2) default 0,
	pressure numeric(8,2) default 0,
	wind_direction numeric(8,2) default 0,
	wind_speed numeric(8,2) default 0
);

insert into measurment_input_params(id, measurment_type_id, height, temperature, pressure, wind_direction,wind_speed )
values(1, 1, 100,12,34,0.2,45);

create sequence measurment_input_params_seq start 2;

alter table measurment_input_params alter column id set default nextval('public.measurment_input_params_seq');

-- Таблица с историей
create table measurment_baths
(
		id integer primary key not null,
		emploee_id integer not null,
		measurment_input_param_id integer not null,
		started timestamp default now()
);


insert into measurment_baths(id, emploee_id, measurment_input_param_id)
values(1, 1, 1);

create sequence measurment_baths_seq start 2;

alter table measurment_baths alter column id set default nextval('public.measurment_baths_seq');

raise notice 'Создание общих справочников и наполнение выполнено успешно'; 

/*
 3. Подготовка расчетных структур
 ==========================================
 */

drop table if exists calc_temperatures_correction;
create table calc_temperatures_correction
(
   temperature numeric(8,2) primary key,
   correction numeric(8,2)
);

insert into public.calc_temperatures_correction(temperature, correction)
Values(0, 0.5),(5, 0.5),(10, 1), (20,1), (25, 2), (30, 3.5), (40, 4.5);

drop type  if exists interpolation_type;
create type interpolation_type as
(
	x0 numeric(8,2),
	x1 numeric(8,2),
	y0 numeric(8,2),
	y1 numeric(8,2)
);

DROP TYPE IF EXISTS public.measure_settings_type;
CREATE TYPE public.measure_settings_type AS
(
	height numeric(8,2),
	temperature numeric(8,2),
	pressure numeric(8,2),
	wind_direction numeric(8,2),
	wind_speed numeric(8,2)
);

-- Таблица с константами
drop table if exists consts;
create table consts
(
	name character varying(50) primary key,
	value text
);

insert into consts
values ('pressure', '750'), ('temperature', '15.9'), 
('temp_min', '-58'), ('temp_max', '58'),
('pressure_min', '500'), ('pressure_max', '900'),
('wind_direction_min', '0'), ('wind_direction_max', '59'),
('wind_speed_min', '0'), ('wind_speed_max', '15');

raise notice 'Расчетные структуры сформированы';

/*
 4. Создание связей
 ==========================================
 */

begin 
	
	alter table public.measurment_baths
	add constraint emploee_id_fk 
	foreign key (emploee_id)
	references public.employees (id);
	
	alter table public.measurment_baths
	add constraint measurment_input_param_id_fk 
	foreign key(measurment_input_param_id)
	references public.measurment_input_params(id);
	
	alter table public.measurment_input_params
	add constraint measurment_type_id_fk
	foreign key(measurment_type_id)
	references public.measurment_types (id);
	
	alter table public.employees
	add constraint military_rank_id_fk
	foreign key(military_rank_id)
	references public.military_ranks (id);

end;

raise notice 'Связи сформированы';
raise notice 'Структура сформирована успешно';

/*
 5. Создание скриптов
 ==========================================
 */
begin
-- Интерполяция
 CREATE OR REPLACE FUNCTION public."interpolation"(var_temperature numeric default 22)
    RETURNS numeric
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
 declare 
 	var_interpolation interpolation_type;
	var_result numeric(8,2) default 0;
	var_min_temparure numeric(8,2) default 0;
	var_max_temperature numeric(8,2) default 0;
	var_denominator numeric(8,2) default 0;
 begin
		raise notice 'Расчет интерполяции для температуры %', var_temperature;

		-- Проверим, возможно температура совпадает со значением в справочнике
		if exists (select 1 from public.calc_temperatures_correction where temperature = var_temperature ) then
		begin
			select correction 
			into  var_result 
			from  public.calc_temperatures_correction
			where 
				temperature = var_temperature;
		end;
		else	
		begin
			-- Получим диапазон в котором работают поправки
			select min(temperature), max(temperature) 
			into var_min_temparure, var_max_temperature
			from public.calc_temperatures_correction;

			if var_temperature < var_min_temparure or   
			   var_temperature > var_max_temperature then

				raise exception 'Некорректно передан параметр! Невозможно рассчитать поправку. Значение должно укладываться в диаппазон: %, %',
					var_min_temparure, var_max_temperature;
			end if;   

			-- Получим граничные параметры

			select x0, y0, x1, y1 
			into var_interpolation.x0, var_interpolation.y0, var_interpolation.x1, var_interpolation.y1
			from
			(
				select t1.temperature as x0, t1.correction as y0
				from public.calc_temperatures_correction as t1
				where t1.temperature <= var_temperature
				order by t1.temperature desc
				limit 1
			) as leftPart
			cross join
			(
				select t1.temperature as x1, t1.correction as y1
				from public.calc_temperatures_correction as t1
				where t1.temperature >= var_temperature
				order by t1.temperature 
				limit 1
			) as rightPart;
			
			raise notice 'Граничные значения %', var_interpolation;

			-- Расчет поправки
			var_denominator := var_interpolation.x1 - var_interpolation.x0;
			if var_denominator = 0.0 then

				raise exception 'Деление на нуль. Возможно, некорректные данные в таблице с поправками!';
			
			end if;
			
                       var_result := (var_temperature - var_interpolation.x0) * (var_interpolation.y1 - var_interpolation.y0) / var_denominator + var_interpolation.y0;
		
		end;
		end if;

	        return var_result;
end;
$BODY$;

-- Функция для формирования переменной из входных данных
CREATE OR REPLACE FUNCTION public."measure_settings_insert"(
	height numeric default 0,
	temperature numeric default 0,
	pressure numeric default 750,
	wind_direction numeric default 0,
	wind_speed numeric default 0
)
    RETURNS measure_settings_type
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
declare
	temp_min integer;
	temp_max integer;
	pressure_min integer;
	pressure_max integer;
	wind_direction_min integer;
	wind_direction_max integer;
	wind_speed_min integer;
	wind_speed_max integer;

	var_measure_settings measure_settings_type;
begin
	select value::integer into temp_min from public.consts where name = 'temp_min';
	select value::integer into temp_max from public.consts where name = 'temp_max';
	select value::integer into pressure_min from public.consts where name = 'pressure_min';
	select value::integer into pressure_max from public.consts where name = 'pressure_max';
	select value::integer into wind_direction_min from public.consts where name = 'wind_direction_min';
	select value::integer into wind_direction_max from public.consts where name = 'wind_direction_max';
	select value::integer into wind_speed_min from public.consts where name = 'wind_speed_min';
	select value::integer into wind_speed_max from public.consts where name = 'wind_speed_max';
	
	if temperature not between temp_min and temp_max 
	or pressure not between pressure_min and pressure_max
	or wind_direction not between wind_direction_min and wind_direction_max
	or wind_speed not between wind_speed_min and wind_speed_max
	then raise exception 'Данные выходят за свои диапазоны!';
	end if;
	var_measure_settings := (height, temperature, pressure, wind_direction, wind_speed);
	return var_measure_settings;
end;
$BODY$;

-- Функции форматирования строк для вывода
---- Дата (ДДЧЧМ)
CREATE OR REPLACE FUNCTION public."fnHeaderTime"(time_var timestamp without time zone default now())
    RETURNS text
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
begin
	return substring(time_var::text, 9, 2) || substring(time_var::text, 12, 2) || substring(time_var::text, 15, 1);
end
$BODY$;

---- Высота над уровнем моря (ВВВВ)
CREATE OR REPLACE FUNCTION public."fnheaderheight"(height numeric default 0)
    RETURNS text
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
begin
	height := height::integer;
	
	if length(height::text) > 4 then
	raise exception 'Слишком длинная для отображения строка';
	end if;
	
	return substring('000', length(height::text)) || height::text;
end
$BODY$;

---- Отклонение давления (БББ)
CREATE OR REPLACE FUNCTION public."fnHeaderPressure"(pressure numeric default 500)
    RETURNS text
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
declare
	dec_start text default '';
begin
	pressure := pressure - (select value::numeric from public.consts where name = 'pressure');
	pressure := pressure::integer;
	if pressure < 0
	then
		dec_start := '5' ;
		pressure := substring(pressure::text, 2);
	end if;
	
	if length(dec_start) + length(pressure::text) >= 4
	then 
		raise exception 'Слишком длинная для отображения строка';
	end if;
	
	return dec_start || substring('00', length(dec_start) + length(pressure::text)) || pressure::text;
end;
$BODY$;

---- Отклонение температуры (ТТ)
CREATE OR REPLACE FUNCTION public."fnHeaderTemperature"(temperature numeric default 22)
    RETURNS text
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
declare
	dec_start text default '';
begin
	temperature := temperature + interpolation(temperature) - (select value::numeric from public.consts where name = 'temperature');
	temperature := temperature::integer;
	
	if length(temperature::text) > 2
	then 
		raise exception 'Слишком длинная для отображения строка';
	end if;
	
	return substring('0', length(temperature::text)) || temperature::text;
end;
$BODY$;
end;
end $$;