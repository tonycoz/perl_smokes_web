-- users, mostly to track down who is submitting bad reports
create table pdc_users (
  id integer not null primary key auto_increment,
  login varchar(20) not null,
  unique login(login)
) Engine=innodb;

-- configurations
create table pdc_perf_configs (
  id integer not null primary key auto_increment,
  owner_id integer not null references pdc_users(id),
  config_name varchar(40) not null,
  unique config_name(config_name)
) Engine=innodb;

-- performance reports
create table pdc_perf_reports (
  id integer not null primary key auto_increment,
  sha varchar(80) not null,
  config_id integer not null
  references pdc_perf_configs(id),
  report_json longblob  not null compressed,
  mod_at datetime not null,
  unique sha_config(sha, config_id)
) Engine=innodb;
