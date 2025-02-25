select name, rank, measures_count, measures_count-correct_data_count as incorrect_data_count from 
(select name, description as rank, count(bchs.id) as measures_count, 
sum(fn_check_for_exception(height, temperature, pressure, wind_direction, wind_speed, bullet_demolition_range))
as correct_data_count
from public.measurment_baths as bchs
inner join public.employees as empls
on bchs.emploee_id = empls.id
inner join public.military_ranks as ranks
on empls.military_rank_id = ranks.id
inner join public.measurment_input_params as params
on params.id = bchs.measurment_input_param_id
group by (name, description))
order by incorrect_data_count desc;