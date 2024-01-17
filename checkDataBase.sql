/*
description: 
	Скрипт проверки студенческой работы квалификационного экзамена по базам данных. 
	Запускается на БД, выдает результаты проверки по критериям, отчет можно увидеть в виде таблицы. 
version: 
	1.0
author: 
	Andrey A. Ivanov
language: 
	T-SQL, MSSQL 2008+
year: 
	2024
*/
declare @objname varchar(7000)=''
declare @objtext varchar(7000)=''
declare @objtype varchar(200)=''
declare @step int=0
declare @title varchar(100)=''
declare @result varchar(100)=''

declare @reptable table(
	step int,
	title varchar(100),
	result varchar(100),
	additional varchar(max)
)

set @step = 4
set @title = 'Названия таблиц и полей самоочевидны, в едином стиле'
print convert(varchar(2),@step) + ' ' + @title
declare @cf int=0
declare @cte int=0
declare @ctr int=0
declare @cfe int=0
declare @cfr int=0
select
	@cf=count(Column_Name),
	@cte=sum(case when TableName like '%[a-z]%' then 1 else 0 end),
	@ctr=sum(case when TableName like '%[а-я]%' then 1 else 0 end),
	@cfe=sum(case when Column_Name like '%[a-z]%' then 1 else 0 end),
	@cfr=sum(case when Column_Name like '%[а-я]%' then 1 else 0 end)
from (
SELECT isc.Table_Name AS TableName ,
 Column_Name
FROM INFORMATION_SCHEMA.COLUMNS isc
 INNER JOIN information_schema.tables ist
 ON isc.table_name = ist.table_name
 INNER JOIN sys.objects o on o.name=ist.TABLE_NAME
 left outer join sys.extended_properties ex on ex.major_id=o.object_id
 WHERE TABLE_TYPE = 'BASE TABLE' and ex.name is null
) tmp
if (@cf=@cte and @cf=@cfe and @ctr=@cfr) or (@cf=@ctr and @cf=@cfr and @cte=@cfe)
begin
	set @result='единый стиль'
	print @result
	insert into @reptable
	select @step,@title,@result,''
end
else
begin
	set @result='присутствует смешение языков'
	print @result
	insert into @reptable
	select @step,@title,@result,''
end
declare objlist cursor static for
SELECT distinct isc.Table_Name AS TableName
FROM INFORMATION_SCHEMA.COLUMNS isc
 INNER JOIN information_schema.tables ist
 ON isc.table_name = ist.table_name
 INNER JOIN sys.objects o on o.name=ist.TABLE_NAME
 left outer join sys.extended_properties ex on ex.major_id=o.object_id
 WHERE TABLE_TYPE = 'BASE TABLE' and ex.name is null
open objlist
fetch next from objlist
into @objname;
if @@CURSOR_ROWS = 0
begin
	print 'Нет данных'
end
while @@FETCH_STATUS=0
begin
	set @objtext=''
	set @result='Таблица '+@objname
	SELECT @objtext=@objtext+Column_Name+' '+Data_Type+(case when Data_Type in ('date','time','int','bigint','float','uniqueidentifier','datetime','datetime2','numeric','smallint','tinyint','bit') then '' else '('+(case when Character_Maximum_Length=-1 then 'MAX' else convert(varchar(10),Character_Maximum_Length) end)+')' end)+'; '
	FROM INFORMATION_SCHEMA.COLUMNS isc
	INNER JOIN information_schema.tables ist ON isc.table_name = ist.table_name
	INNER JOIN sys.objects o on o.name=ist.TABLE_NAME
	WHERE isc.Table_Name=@objname
	ORDER BY Ordinal_position;
	print @result
	print @objtext

	insert into @reptable
	select @step,@title,@result,isnull(@objtext,'что-то пошло не так')

	fetch next from objlist
	into @objname;
end
close objlist;
deallocate objlist;


set @step = 5
set @title = 'Типы данных подобраны верно'
declare objlist cursor static for
select
	TableName, Column_Name, Data_Type
from (
SELECT isc.Table_Name AS TableName ,
 Column_Name ,
 Data_Type ,
 Character_Maximum_Length
FROM INFORMATION_SCHEMA.COLUMNS isc
 INNER JOIN information_schema.tables ist
 ON isc.table_name = ist.table_name
 INNER JOIN sys.objects o on o.name=ist.TABLE_NAME
 left outer join sys.extended_properties ex on ex.major_id=o.object_id
 WHERE TABLE_TYPE = 'BASE TABLE' and ex.name is null
 and Data_Type in ('varchar','nvarchar') and Character_Maximum_Length=-1
) tmp
open objlist
fetch next from objlist
into @objname,@objtext,@objtype;
if @@CURSOR_ROWS = 0
begin
	set @result='Отсутствуют varchar(MAX), nvarchar(MAX)'
	print @result
	insert into @reptable
	select @step,@title,@result,''
end
while @@FETCH_STATUS=0
begin
	set @result='Таблица '+@objname+' поле '+@objtext+' возможное несоответствие типа'

	print @result
	insert into @reptable
	select @step,@title,@result,''

	fetch next from objlist
	into @objname,@objtext,@objtype;
end
close objlist;
deallocate objlist;

set @step = 6
set @title = 'Созданы ограничения на связи между сущностями'
SELECT @objname=count(f.name)
FROM sys.foreign_keys AS f
INNER JOIN sys.foreign_key_columns AS fc ON f.OBJECT_ID = fc.constraint_object_id
INNER JOIN sys.objects AS o ON o.OBJECT_ID = fc.referenced_object_id
if @objname>0
begin
	set @result='Связи созданы'
	print @result
	insert into @reptable
	select @step,@title,@result,''
end
else
begin
	set @result='Нет связей'
	print @result
	insert into @reptable
	select @step,@title,@result,''
end

set @step = 8
set @title = 'Соблюдается целостность данных'
SELECT @objname=isnull(sum(case when f.delete_referential_action_desc='CASCADE' then 1 else 0 end),0),
 @objtext=isnull(sum(case when f.update_referential_action_desc='CASCADE' then 1 else 0 end),0)
FROM sys.foreign_keys AS f
INNER JOIN sys.foreign_key_columns AS fc ON f.OBJECT_ID = fc.constraint_object_id
INNER JOIN sys.objects AS o ON o.OBJECT_ID = fc.referenced_object_id
if (@objname>0 or @objtext>0)
begin
	set @result='Целостность данных обеспечена'
	print @result
	insert into @reptable
	select @step,@title,@result,''
end
else
begin
	set @result='Целостность данных не обеспечивается'
	print @result
	insert into @reptable
	select @step,@title,@result,''
end

set @step = 10
set @title = 'Данные загружены в разработанную базу данных'
declare @recall bigint=0
declare objlist cursor static for
	SELECT OBJECT_NAME(p.object_id) AS TableName ,SUM(p.Rows) AS cRows
	FROM sys.partitions p
	JOIN sys.indexes i ON i.object_id = p.object_id AND i.index_id = p.index_id
	left outer join sys.extended_properties ex on ex.major_id=p.object_id
	WHERE i.type_desc IN ( 'CLUSTERED', 'HEAP' ) AND OBJECT_SCHEMA_NAME(p.object_id) <> 'sys' and ex.name is null
	GROUP BY p.object_id, i.type_desc, i.Name
	ORDER BY TableName;

open objlist
fetch next from objlist
into @objname,@objtext;
if @@CURSOR_ROWS = 0
begin
	print 'нет данных'
end
while @@FETCH_STATUS=0
begin
	print 'Таблица '+@objname+' записей '+@objtext
	set @recall=+convert(bigint,@objtext)
	fetch next from objlist
	into @objname,@objtext;
end
close objlist;
deallocate objlist;
if @recall>0
begin
	set @result='Данные загружены'
	print @result
	insert into @reptable
	select @step,@title,@result,''
end
else
begin
	set @result='Данные не загружены'
	print @result
	insert into @reptable
	select @step,@title,@result,''
end

set @step = 12
set @title = 'Правильно подобран вид функции'
declare objlist cursor static for
	SELECT o.name AS 'ProcName' ,
			sm.[DEFINITION] AS 'Proc script',
			o.type_desc
	FROM sys.objects o
			INNER JOIN sys.sql_modules sm ON o.object_id = sm.OBJECT_ID
	WHERE o.type_desc in ('SQL_SCALAR_FUNCTION','SQL_INLINE_TABLE_VALUED_FUNCTION','SQL_TABLE_VALUED_FUNCTION') and o.is_ms_shipped=0 and o.name not like 'fn_%'
	ORDER BY o.NAME;

open objlist
fetch next from objlist
into @objname,@objtext,@objtype;
if @@CURSOR_ROWS = 0
begin
	set @result='нет данных'
	print @result
	insert into @reptable
	select @step,@title,@result,'отсутствуют данные для проверки'
end
while @@FETCH_STATUS=0
begin
	if @objtype='SQL_SCALAR_FUNCTION'
	begin
	set @result='Скалярная функция '+@objname
	end
	if @objtype in ('SQL_INLINE_TABLE_VALUED_FUNCTION','SQL_TABLE_VALUED_FUNCTION')
	begin
	set @result='Табличная функция '+@objname
	end

	print @result
	insert into @reptable
	select @step,@title,@result,''

	fetch next from objlist
	into @objname,@objtext,@objtype;
end
close objlist;
deallocate objlist;

set @step = 13
set @title = 'Функция выполнена согласно заданию'
declare objlist cursor static for
	SELECT o.name AS 'ProcName' ,
			sm.[DEFINITION] AS 'Proc script',
			o.type_desc
	FROM sys.objects o
			INNER JOIN sys.sql_modules sm ON o.object_id = sm.OBJECT_ID
	WHERE o.type_desc in ('SQL_SCALAR_FUNCTION','SQL_INLINE_TABLE_VALUED_FUNCTION','SQL_TABLE_VALUED_FUNCTION') and o.is_ms_shipped=0 and o.name not like 'fn_%'
	ORDER BY o.NAME;

open objlist
fetch next from objlist
into @objname,@objtext,@objtype;
if @@CURSOR_ROWS = 0
begin
	set @result='нет данных'
	print @result
	insert into @reptable
	select @step,@title,@result,'отсутствуют данные для проверки'
end

while @@FETCH_STATUS=0
begin
	print '====== SQL_FUNCTION ======'
	if @objtype='SQL_SCALAR_FUNCTION'
	begin
	set @result='Скалярная функция '+@objname
	end
	if @objtype in ('SQL_INLINE_TABLE_VALUED_FUNCTION','SQL_TABLE_VALUED_FUNCTION')
	begin
	set @result='Табличная функция '+@objname
	end
	print @result
	print '====== начало текста ======'
	print ltrim(rtrim(@objtext))
	print '====== конец текста ======'

	insert into @reptable
	select @step,@title,@result,@objtext

	fetch next from objlist
	into @objname,@objtext,@objtype;
end
close objlist;
deallocate objlist;

set @step = 14
set @title = 'Представление выполнено согласно заданию'
declare objlist cursor static for
	SELECT isc.Table_Name ,
			count(Column_Name)
	FROM INFORMATION_SCHEMA.COLUMNS isc
	INNER JOIN information_schema.tables ist ON isc.table_name = ist.table_name
	WHERE TABLE_TYPE = 'View'
	GROUP BY isc.Table_Name
	ORDER BY isc.Table_Name;

open objlist
fetch next from objlist
into @objname,@objtype;
if @@CURSOR_ROWS = 0
begin
	set @result='нет данных'
	print @result
	insert into @reptable
	select @step,@title,@result,'отсутствуют данные для проверки'
end

while @@FETCH_STATUS=0
begin
	set @result='Предствление '+@objname+' Количество полей '+@objtype
	print @result
	set @objtext=''
	SELECT @objtext=@objtext+Column_Name+';'
	FROM INFORMATION_SCHEMA.COLUMNS isc
	INNER JOIN information_schema.tables ist ON isc.table_name = ist.table_name
	WHERE TABLE_TYPE = 'View' and ist.table_name=@objname
	ORDER BY Ordinal_position;
	print @objtext

	SELECT @objtext=sm.[DEFINITION]
	FROM sys.objects o
	INNER JOIN sys.sql_modules sm ON o.object_id = sm.OBJECT_ID
	WHERE o.name =@objname

	insert into @reptable
	select @step,@title,@result,@objtext

	fetch next from objlist
	into @objname,@objtext;
end
close objlist;
deallocate objlist;

set @step = 15
set @title = 'В хранимой процедуре предусмотрена проверка данных'
declare objlist cursor static for
	SELECT o.name AS 'ProcName' ,
			sm.[DEFINITION] AS 'Proc script',
			o.type_desc
	FROM sys.objects o
			INNER JOIN sys.sql_modules sm ON o.object_id = sm.OBJECT_ID
	WHERE o.type_desc = 'SQL_STORED_PROCEDURE' and o.is_ms_shipped=0 and o.name not like 'sp_%'
	ORDER BY o.NAME;

open objlist
fetch next from objlist
into @objname,@objtext,@objtype;
if @@CURSOR_ROWS = 0
begin
	set @result='нет данных'
	print @result
	insert into @reptable
	select @step,@title,@result,'отсутствуют данные для проверки'
end

while @@FETCH_STATUS=0
begin
	if @objtext like '%if %'
	begin
	set @result='Оператор условия есть в хранимой процедуре '+@objname
	end
	else
	begin
	set @result='Оператор условия отсутствует в хранимой процедуре '+@objname
	end

	print @result
	insert into @reptable
	select @step,@title,@result,''

	fetch next from objlist
	into @objname,@objtext,@objtype;
end
close objlist;
deallocate objlist;

set @step = 16
set @title = 'Хранимая процедура выполнена согласно заданию'
declare objlist cursor static for
	SELECT o.name AS 'ProcName' ,
			sm.[DEFINITION] AS 'Proc script',
			o.type_desc
	FROM sys.objects o
			INNER JOIN sys.sql_modules sm ON o.object_id = sm.OBJECT_ID
	WHERE o.type_desc = 'SQL_STORED_PROCEDURE' and o.is_ms_shipped=0 and o.name not like 'sp_%'
	ORDER BY o.NAME;

open objlist
fetch next from objlist
into @objname,@objtext,@objtype;
if @@CURSOR_ROWS = 0
begin
	set @result='нет данных'
	print @result
	insert into @reptable
	select @step,@title,@result,'отсутствуют данные для проверки'
end

while @@FETCH_STATUS=0
begin
	print '====== SQL_STORED_PROCEDURE ======'
	set @result=@objname
	print '====== начало текста ======'
	print ltrim(rtrim(@objtext))
	print '====== конец текста ======'

	insert into @reptable
	select @step,@title,@result,@objtext

	fetch next from objlist
	into @objname,@objtext,@objtype;
end
close objlist;
deallocate objlist;

print '17. Триггер выполняет поставленную задачу согласно условию'
set @step = 18
set @title = 'Аудит выполняет поставленную задачу согласно условию'
declare objlist cursor static for
	SELECT o.name AS 'ProcName' ,
			sm.[DEFINITION] AS 'Proc script',
			o.type_desc
	FROM sys.objects o
			INNER JOIN sys.sql_modules sm ON o.object_id = sm.OBJECT_ID
	WHERE o.type_desc = 'SQL_TRIGGER' and o.is_ms_shipped=0 and o.name not like 'sp_%'
	ORDER BY o.NAME;

open objlist
fetch next from objlist
into @objname,@objtext,@objtype;
if @@CURSOR_ROWS = 0
begin
	set @result='нет данных'
	print @result
	insert into @reptable
	select @step,@title,@result,'отсутствуют данные для проверки'
end

while @@FETCH_STATUS=0
begin
	set @result=@objname
	print '====== начало текста ======'
	print ltrim(rtrim(@objtext))
	print '====== конец текста ======'

	insert into @reptable
	select @step,@title,@result,@objtext

	fetch next from objlist
	into @objname,@objtext,@objtype;
end
close objlist;
deallocate objlist;

set @step = 19
set @title = 'Объекты имеют имена согласно заданным условиям'
declare objlist cursor static for
	SELECT o.name AS 'ProcName' ,
			o.type_desc
	FROM sys.objects o
			INNER JOIN sys.sql_modules sm ON o.object_id = sm.OBJECT_ID
	WHERE o.type_desc in ('SQL_STORED_PROCEDURE','SQL_SCALAR_FUNCTION','SQL_TRIGGER','SQL_INLINE_TABLE_VALUED_FUNCTION','SQL_TABLE_VALUED_FUNCTION','VIEW') and o.is_ms_shipped=0 and (o.name not like 'sp_%' and o.name not like 'fn_%')
	ORDER BY o.NAME;
open objlist
fetch next from objlist
into @objname,@objtype;
if @@CURSOR_ROWS = 0
begin
	set @result='нет данных'
	print @result
	insert into @reptable
	select @step,@title,@result,'отсутствуют данные для проверки'
end

while @@FETCH_STATUS=0
begin
	set @result=@objname + ' ' + ltrim(rtrim(@objtype))
	print @result
	insert into @reptable
	select @step,@title,@result,''

	fetch next from objlist
	into @objname,@objtype;
end
close objlist;
deallocate objlist;


select step,title,result,ltrim(rtrim(additional)) additional from @reptable
order by step,additional

SELECT convert(varchar(2),step)+' '+title AS h1,result AS h2, replace(additional,';',CHAR(13)+CHAR(10)) as pre
FROM @reptable
order by step,additional
FOR XML RAW('div'),ELEMENTS, root('div')
