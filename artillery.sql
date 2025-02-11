-- Создание таблиц
-- Справочник должностей
create table if not exists public.military_ranks
(
	id integer primary key not null default nextval('military_ranks_seq'::regclass),
	description character varying(255)
);

insert into military_ranks(id, description)
values(1,'Рядовой'),(2,'Лейтенант') on conflict do nothing;

-- Пользователи
create table if not exists employees
(
    id integer primary key not null default nextval('employees_seq'::regclass),
	name text,
	birthday timestamp ,
	military_rank_id integer
);

insert into employees(id, name, birthday, military_rank_id)  
values(1, 'Воловиков Александр Сергеевич','1978-06-24', 2) on conflict do nothing;

-- Устройства для измерения
create table if not exists measurment_types
(
   id integer primary key not null default nextval('measurment_types_seq'::regclass),
   short_name character varying(50),
   description text 
);

insert into measurment_types(id, short_name, description)
values(1, 'ДМК', 'Десантный метео комплекс'),
(2,'ВР','Ветровое ружье') on conflict do nothing;

-- Таблица с параметрами
create table if not exists measurment_input_params
(
    id integer primary key not null default nextval('measurment_input_params_seq'::regclass),
	measurment_type_id integer not null,
	height numeric(8,2) default 0,
	temperature numeric(8,2) default 0,
	pressure numeric(8,2) default 0,
	wind_direction numeric(8,2) default 0,
	wind_speed numeric(8,2) default 0
);

insert into measurment_input_params(id, measurment_type_id, height, temperature, pressure, wind_direction, wind_speed)
values(1, 1, 100,12,34,0.2,45) on conflict do nothing;

-- Таблица с историей
create table if not exists measurment_batches
(
		id integer primary key not null default nextval('measurment_batches_seq'::regclass),
		employee_id integer not null,
		measurment_input_param_id integer not null,
		started timestamp default now()
);


insert into measurment_batches(id, employee_id, measurment_input_param_id)
values(1, 1, 1) on conflict do nothing;

-- Таблица поправок по температуре (Таблица 1)
create table if not exists temperature
(
	id integer primary key not null default nextval('temperature_seq'::regclass),
	temperature numeric(4,2),
	delta numeric(4,2)
);

insert into temperature
values
(1, 0, 0),
(2, 5, 0.5),
(3, 15, 1),
(4, 20, 1.5),
(5, 25, 2),
(6, 30, 3.5),
(7, 40, 4.5) on conflict do nothing;


-- Создание связей
alter table public.employees
drop constraint if exists military_rank_id_constraint,
add constraint military_rank_id_constraint
foreign key (military_rank_id)
references public.military_ranks(id);

alter table public.measurment_input_params
drop constraint if exists measurment_type_id_constraint,
add constraint measurment_type_id_constraint
foreign key (measurment_type_id)
references public.measurment_types(id);

alter table public.measurment_batches
drop constraint if exists employee_id_constraint,
add constraint employee_id_constraint
foreign key (employee_id)
references public.employees(id);

alter table public.measurment_batches
drop constraint if exists measurment_input_param_id_constraint,
add constraint measurment_input_param_id_constraint
foreign key (measurment_input_param_id)
references public.measurment_input_params(id);


-- Создание типа данных interpolation
DROP TYPE IF EXISTS public.interpolation_params;
CREATE TYPE public.interpolation_params AS
(
	x0 numeric(4,2),
	x1 numeric(4,2),
	y0 numeric(4,2),
	y1 numeric(4,2),
	x numeric(4,2)
);