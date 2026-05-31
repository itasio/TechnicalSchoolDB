--
-- PostgreSQL database dump
--

\restrict T3Tydlfqo2LSG45fRfdghpBC8JK1JztkReAVwvhh7gfIsu7ZmQAtIYcLk4UAhtf

-- Dumped from database version 13.23 (Debian 13.23-1.pgdg13+1)
-- Dumped by pg_dump version 13.23

-- Started on 2026-05-31 16:40:59 UTC

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 692 (class 1247 OID 16386)
-- Name: LabModule_type; Type: TYPE; Schema: public; Owner: postgresUser
--

CREATE TYPE public."LabModule_type" AS ENUM (
    'project',
    'lab_excercise'
);


ALTER TYPE public."LabModule_type" OWNER TO "postgresUser";

--
-- TOC entry 695 (class 1247 OID 16392)
-- Name: course_dependency_mode_type; Type: TYPE; Schema: public; Owner: postgresUser
--

CREATE TYPE public.course_dependency_mode_type AS ENUM (
    'required',
    'recommended'
);


ALTER TYPE public.course_dependency_mode_type OWNER TO "postgresUser";

--
-- TOC entry 698 (class 1247 OID 16398)
-- Name: level_type; Type: TYPE; Schema: public; Owner: postgresUser
--

CREATE TYPE public.level_type AS ENUM (
    'A',
    'B',
    'C',
    'D'
);


ALTER TYPE public.level_type OWNER TO "postgresUser";

--
-- TOC entry 701 (class 1247 OID 16408)
-- Name: rank_type; Type: TYPE; Schema: public; Owner: postgresUser
--

CREATE TYPE public.rank_type AS ENUM (
    'full',
    'associate',
    'assistant',
    'lecturer'
);


ALTER TYPE public.rank_type OWNER TO "postgresUser";

--
-- TOC entry 704 (class 1247 OID 16418)
-- Name: register_status_type; Type: TYPE; Schema: public; Owner: postgresUser
--

CREATE TYPE public.register_status_type AS ENUM (
    'proposed',
    'requested',
    'approved',
    'rejected',
    'pass',
    'fail'
);


ALTER TYPE public.register_status_type OWNER TO "postgresUser";

--
-- TOC entry 707 (class 1247 OID 16432)
-- Name: semester_season_type; Type: TYPE; Schema: public; Owner: postgresUser
--

CREATE TYPE public.semester_season_type AS ENUM (
    'winter',
    'spring'
);


ALTER TYPE public.semester_season_type OWNER TO "postgresUser";

--
-- TOC entry 710 (class 1247 OID 16438)
-- Name: semester_status_type; Type: TYPE; Schema: public; Owner: postgresUser
--

CREATE TYPE public.semester_status_type AS ENUM (
    'past',
    'present',
    'future'
);


ALTER TYPE public.semester_status_type OWNER TO "postgresUser";

--
-- TOC entry 227 (class 1255 OID 16445)
-- Name: adapt_surname(character, character); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.adapt_surname(surname character, sex character) RETURNS character
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
result character(50);
BEGIN
result = surname;
IF right(surname,2)<>'ΗΣ' THEN
RAISE NOTICE 'Cannot handle this surname';
ELSIF sex='F' THEN
result = left(surname,-1);
ELSIF sex<>'M' THEN
RAISE NOTICE 'Wrong sex parameter';
END IF;
RETURN result;
END;
$$;


ALTER FUNCTION public.adapt_surname(surname character, sex character) OWNER TO "postgresUser";

--
-- TOC entry 228 (class 1255 OID 16446)
-- Name: calculate_final_grade5_3(); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.calculate_final_grade5_3() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	
BEGIN
		IF TG_OP = 'UPDATE' then--Checking past register status for pass/fail (in Update case) to prohibit update
			if old.register_status = 'pass'::register_status_type or old.register_status = 'fail'::register_status_type then
				raise notice 'update prohibited';
				return null;
			end if;
		END IF;
		if new.register_status = 'pass'::register_status_type or new.register_status = 'fail'::register_status_type--Status depends only on grades 
			or new.register_status = 'rejected'::register_status_type --Cant participate in exams and labs
			or new.register_status = 'proposed'::register_status_type --Waitting to be accepted in semester->Cant participate in exams and labs
			or new.register_status = 'requested'::register_status_type then----Waitting to be accepted in semester->Cant participate in exams and labs
				raise notice 'prohibited';
				return null;
		
		
		elsif new.register_status = 'approved'::register_status_type then  --Allowed to calculate final grade
			if(new.course_code in (select course_code from "Course" where  lab_hours=0)) then --Fixing final grade for INSERT/UPDATE with course WITHOUT LAB
				--raise notice 'Fixing final grade for INSERT whith course WITHOUT LAB';
				new.final_grade= new.exam_grade;
				new.register_status= case
										when new.exam_grade>=noLabs.exam_min then 'pass'::register_status_type
										else 'fail'::register_status_type
									 end
						from (select * from "CourseRun" c
							  where  c.course_code=new.course_code and c.serial_number=NEW.serial_number  ) as noLabs;
				--raise notice 'bEFORE RETURN';
				RETURN NEW;
			--end if;
			elsif(new.course_code in (select course_code from "Course" where  lab_hours>0)) then --Fixing final grade for INSERRT whith course WITH LAB	
				new.register_status = case
										when new.exam_grade>=withLabs.exam_min and new.lab_grade>=withLabs.lab_min then 'pass'::register_status_type
										else 'fail'::register_status_type
									  end
					from (select exam_min, lab_min from "CourseRun" c
						where c.course_code = new.course_code and c.serial_number=NEW.serial_number) as withLabs;

				new.final_grade = case
									when NEW.exam_grade>=withLabs.exam_min and new.lab_grade>=withLabs.lab_min then (round((new.exam_grade*withLabs.exam_percentage*0.01)+(new.lab_grade*(1-withLabs.exam_percentage*0.01)),0))
									when NEW.lab_grade < withLabs.lab_min then 0
									when NEW.exam_grade < withLabs.exam_min then new.exam_grade
									else null
								  end			  

				from (select * from "CourseRun" c
						where c.course_code = new.course_code and c.serial_number=NEW.serial_number) as withLabs;
				RETURN NEW;
			end if;

				--RETURN NEW;	
		
		end if;	
	

	
	
	

END;
$$;


ALTER FUNCTION public.calculate_final_grade5_3() OWNER TO "postgresUser";

--
-- TOC entry 229 (class 1255 OID 16447)
-- Name: check_max_committee_members5_1(); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.check_max_committee_members5_1() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin

if 
	(select count(prof_amka) as members --the number of members that currently has a committee for specific Diploma
	 from "Committee"
	 where diploma_num = new.diploma_num and stud_amka = new.stud_amka) 

	>= 

	(select committe_members_no --max number of committee members for current year
	 from "School_Rules"
	 where year = (select academic_year 
			  	   from "Semester"
			  	   where semester_status = 'present')) then
		raise notice 'This Committee has reached the max number of members for this Diploma';
		return null;
end if;
	Return NEW;
end;
$$;


ALTER FUNCTION public.check_max_committee_members5_1() OWNER TO "postgresUser";

--
-- TOC entry 230 (class 1255 OID 16448)
-- Name: check_max_workgroup_members5_1(); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.check_max_workgroup_members5_1() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin

if 
	(select count(student_amka) as members --the number of members that currently has a workGroup
	 from "joins"
	 where course_code = new.course_code and "workGroup_id" = new."workGroup_id") 

	>= 

	(SELECT max_member
	 FROM "LabModule"
	 WHERE module_no = new.module_no) then
		raise notice 'This Workgroup has reached the max number of members for this Labmodule';
		return null;
end if;

Return New;
end;
$$;


ALTER FUNCTION public.check_max_workgroup_members5_1() OWNER TO "postgresUser";

--
-- TOC entry 231 (class 1255 OID 16449)
-- Name: check_register_criterions5_4(); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.check_register_criterions5_4() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
maxCourses bigint := 6;
maxUnits bigint := 20;
rec record;
begin

if TG_OP = 'INSERT' then
	if new.register_status = 'approved' or new.register_status = 'rejected' then
		raise notice 'insert prohibited';
		return null;
	end if;
elsif TG_OP = 'UPDATE' then
	if old.register_status = 'rejected' or new.register_status = 'approved' or new.register_status = 'rejected' then
		raise notice 'update prohibited';
		return null;
	end if;
end if;

if (TG_OP = 'INSERT' and new.register_status = 'requested') or (TG_OP = 'UPDATE' and old.register_status = 'proposed' and new.register_status = 'requested') then
	if 		((select count(course_code) -- the number of courses that the student wants to register or is registered
			from "Register" 		  --must be <= maxCourses !!!
			where  amka = new.amka and (register_status = 'requested' or register_status = 'approved')) + 1 > maxCourses)	--add 1 because the new register was not accounted in the table
		or
		   ((select sum(units)	--sum of units for the courses that the student wants to register or is registered
		   from				--must be <= maxUnits
				((select course_code -- the number of courses that the student wants to register or is registered
				  from "Register" 		  
				  where  amka = new.amka and (register_status = 'requested' or register_status = 'approved')) t1
						natural join
				 (select course_code, units from "Course")t2 )t3) 
										+ (select units::bigint from "Course" where course_code = new.course_code) > maxUnits)	--add units of new course because it is not inserted yet in the table
	then
		new.register_status = 'rejected';
		raise notice 'registration rejected';
		return null;
	end if;
	
	--we will search for every required course if it is in the list of passed courses of the student
	for rec in	(select main 		--the required courses that must have been passed for the requested course
				from "Course_depends"
				where mode = 'required' and dependent = new.course_code)
	loop
		if (select exists(select 
						  from (select course_code -- the courses that the student has passed
								from "Register" 		  
								where  amka = new.amka and register_status = 'pass')gg 
						  where course_code=new.course_code) = 'false') then
		 	new.register_status = 'rejected';
			raise notice 'registration rejected';
			return null;
		 end if;
	end loop;
	
	new.register_status = 'approved';	--all the criterions are successful
	raise notice 'registration approved';
	return new;
end if;
Return new;
end;
$$;


ALTER FUNCTION public.check_register_criterions5_4() OWNER TO "postgresUser";

--
-- TOC entry 232 (class 1255 OID 16450)
-- Name: convert_latin(character varying); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.convert_latin(tname character varying) RETURNS character varying
    LANGUAGE sql
    AS $$select 
replace(
replace(
replace(
replace(
replace(
replace(
replace(
replace(
replace(
replace(
replace(
replace(
replace(
replace(
replace(
replace(
replace(
replace(
replace(
replace(
replace(
replace(
replace(
replace(tname	
,'Α','a')
,'Β','b')
,'Γ','g')
,'Δ','d')
,'Ε','e')
,'Ζ','z')
,'Η','i')
,'Θ','th')
,'Ι','i')
,'Κ','k')
,'Λ','l')
,'Μ','m')
,'Ν','n')
,'Ξ','ks')
,'Ο','o')
,'Π','p')
,'Ρ','r')
,'Σ','s')
,'Τ','t')
,'Υ','y')
,'Φ','f')
,'Χ','x')
,'Ψ','ps')
,'Ω','o')
from "Surname"$$;


ALTER FUNCTION public.convert_latin(tname character varying) OWNER TO "postgresUser";

--
-- TOC entry 233 (class 1255 OID 16451)
-- Name: create_am(integer, integer); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.create_am(year integer, num integer) RETURNS character
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
RETURN concat(year::character(4),lpad(num::text,6,'0'));
END;
$$;


ALTER FUNCTION public.create_am(year integer, num integer) OWNER TO "postgresUser";

--
-- TOC entry 234 (class 1255 OID 16452)
-- Name: create_future_courseruns5_5(); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.create_future_courseruns5_5() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE 
	course record;
	max_serial_number integer;
BEGIN
	
	max_serial_number := (select max(serial_number)+1 from "CourseRun");
	
	for course in(select *
				  from "Course" c
				 	where c.typical_season=new.academic_season)
	loop
		--Creating new CourseRun as if the course does not have a lab
		Insert into "CourseRun"(course_code, serial_number,exam_min, lab_min, exam_percentage,labuses,semesterrunsin)
		Values( course.course_code, max_serial_number,0 ,0 ,0 ,null , new.semester_id);
		
		--If course does have lab then we update exam_min, lab_min, exam_percentage,labuses
		--Where exam_min, lab_min, exam_percentage are random 
		--and labuses is a random lab whose sector covers the teaching material of the course
		IF (course.lab_hours>0) then
		--raise notice 'course with labs!';
			if (substring(course.course_code,1,3)='ΣΥΣ' 
				or substring(course.course_code,1,3)='ΤΗΛ'
				or substring(course.course_code,1,3)='ΜΠΔ'
				or substring(course.course_code,1,3)='ΦΥΣ'
				or substring(course.course_code,1,3)='ΕΝΕ') then
				raise notice 'course with labs!';
					UPDATE "CourseRun" cr
					set exam_min= floor(random() * (6-4+1) + 4)::int ,
						lab_min= floor(random() * (6-4+1) + 4)::int  ,
						exam_percentage=(floor(random() * (9-1+1) + 1)::int )*10,
						labuses=(SELECT "Lab".lab_code FROM "Lab" where "Lab".sector_code=1
									ORDER BY random() LIMIT 1)
					where cr.course_code=course.course_code and  cr.semesterrunsin=new.semester_id;
			elsif (substring(course.course_code,1,3)='ΕΚΠ') then 
			raise notice 'course with labs!';
				   UPDATE "CourseRun" cr
					set exam_min= floor(random() * (6-4+1) + 4)::int ,
						lab_min= floor(random() * (6-4+1) + 4)::int  ,
						exam_percentage=(floor(random() * (9-1+1) + 1)::int )*10,
						labuses=(SELECT "Lab".lab_code FROM "Lab" where "Lab".sector_code=2
									ORDER BY random() LIMIT 1)
					where cr.course_code=course.course_code and  cr.semesterrunsin=new.semester_id;
			elsif (substring(course.course_code,1,3)='ΠΛΗ') then 
			raise notice 'course with labs!';
				   UPDATE "CourseRun" cr
					set exam_min= floor(random() * (6-4+1) + 4)::int ,
						lab_min= floor(random() * (6-4+1) + 4)::int  ,
						exam_percentage=(floor(random() * (9-1+1) + 1)::int )*10,
						labuses=(SELECT "Lab".lab_code FROM "Lab" where "Lab".sector_code=3
									ORDER BY random() LIMIT 1)
					where cr.course_code=course.course_code and  cr.semesterrunsin=new.semester_id;
			elsif ( substring(course.course_code,1,3)='ΗΡΥ') then 
			raise notice 'course with labs!';
				   UPDATE "CourseRun" cr
					set exam_min= floor(random() * (6-4+1) + 4)::int ,
						lab_min= floor(random() * (6-4+1) + 4)::int  ,
						exam_percentage=(floor(random() * (9-1+1) + 1)::int )*10,
						labuses=(SELECT "Lab".lab_code FROM "Lab" where "Lab".sector_code=4
									ORDER BY random() LIMIT 1)
					where cr.course_code=course.course_code and  cr.semesterrunsin=new.semester_id;
			elsif (substring(course.course_code,1,3)='ΜΑΘ') then 
			raise notice 'course with labs!';
				   UPDATE "CourseRun" cr
					set exam_min= floor(random() * (6-4+1) + 4)::int ,
						lab_min= floor(random() * (6-4+1) + 4)::int  ,
						exam_percentage=(floor(random() * (9-1+1) + 1)::int )*10,
						labuses=(SELECT "Lab".lab_code FROM "Lab" where "Lab".sector_code=5
									ORDER BY random() LIMIT 1)
					where cr.course_code=course.course_code and  cr.semesterrunsin=new.semester_id;
			end if;
		END IF;


------------------------------------------------------------------------------------------
		INSERT INTO "Teaches"
			select prof.amka, cr.serial_number,  course.course_code
			from (SELECT "Professor".amka FROM "Professor" 
				  		where "Professor".labjoins=(select a.labuses from "CourseRun" a
													where a.course_code=course.course_code and a.semesterrunsin=new.semester_id)
						ORDER BY random() LIMIT 1) as prof
				, (SELECT serial_number from "CourseRun" a
							where a.course_code=course.course_code and a.semesterrunsin=new.semester_id) as  cr
				group by prof.amka, cr.serial_number;	
		
	end loop;

	RETURN null;


END;
$$;


ALTER FUNCTION public.create_future_courseruns5_5() OWNER TO "postgresUser";

--
-- TOC entry 235 (class 1255 OID 16453)
-- Name: create_persons(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.create_persons(num integer, start_year integer, end_year integer) RETURNS TABLE(amka character varying, name character varying, father_name character varying, surname character varying, email character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
	RETURN QUERY
	SELECT a.amka, n.name, f.name, adapt_surname(s.surname,n.sex)::varchar,concat(convert_latin(s.surname),right(a.amka::text,4),'@tuc.gr')::varchar
	FROM 
		random_names(num) n JOIN 
		random_names(num) f USING (id) JOIN
		random_surnames(num) s USING (id) JOIN
		random_amka(num, start_year, end_year) a USING (id);
END;
$$;


ALTER FUNCTION public.create_persons(num integer, start_year integer, end_year integer) OWNER TO "postgresUser";

--
-- TOC entry 247 (class 1255 OID 16454)
-- Name: createtablea(); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.createtablea() RETURNS TABLE(amka character varying)
    LANGUAGE plpgsql
    AS $$

BEGIN

    RETURN QUERY 
	select  stud1.amka from(select DISTINCT B.amka from ("Register" R natural join "Student" s natural join "Semester" sem)B
		where ((cast(left((cast(B.entry_date as text)),4) as integer))+4) <= (select academic_year From "Semester" where semester_status='present') 
			and  B.semester_status='present')  as stud1
			where NOT EXISTS (SELECT * FROM "Diploma" as stud2
							 where stud1.amka = stud2.student_am);
END;

$$;


ALTER FUNCTION public.createtablea() OWNER TO "postgresUser";

--
-- TOC entry 248 (class 1255 OID 16455)
-- Name: finalise_grades(integer); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.finalise_grades(sem_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$

DECLARE 
    latestGrade numeric;
	
BEGIN

	PERFORM  public.insert_grades(sem_id);
	
	UPDATE "Register" r
	SET final_grade = r.exam_grade,
		register_status = case
							when r.exam_grade>=noLabs.exam_min then 'pass'::register_status_type
							else 'fail'::register_status_type
						  end
		from (select * from "Register" natural join "CourseRun"
				where semesterrunsin = (select semester_id from "Semester"
												where semester_status='present') 
					  and labuses is null) as noLabs

	where noLabs.course_code = r.course_code and noLabs.serial_number = r.serial_number and noLabs.register_status = 'approved'; --Updating grades of classes with no labs
	
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	
	UPDATE "Register" r
	SET register_status = case
							when r.exam_grade>=withLabs.exam_min and r.lab_grade>=withLabs.lab_min then 'pass'::register_status_type
							else 'fail'::register_status_type
					  	  end,
		
		final_grade = case
							when r.exam_grade>=withLabs.exam_min and r.lab_grade>=withLabs.lab_min then (round((r.exam_grade*tmp.exam_percentage*0.01)+(r.lab_grade*(1-tmp.exam_percentage*0.01)),0))
							when r.lab_grade < withLabs.lab_min then 0
							when r.exam_grade < withLabs.exam_min then r.exam_grade
							else null
						  end			  
		
		from (select * from "Register" natural join "CourseRun"
				where semesterrunsin = (select semester_id from "Semester"
												where semester_status='present') 
					  and labuses is not null) as withLabs

	where withLabs.course_code = r.course_code and withLabs.serial_number = r.serial_number and withLabs.register_status = 'approved'; --Updating grades of classes with no labs
	
	
END;

$$;


ALTER FUNCTION public.finalise_grades(sem_id integer) OWNER TO "postgresUser";

--
-- TOC entry 250 (class 1255 OID 16456)
-- Name: finalise_grades2_3(integer); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.finalise_grades2_3(sem_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$

DECLARE 
    latestGrade numeric;
	
BEGIN

	PERFORM  public.insert_grades(sem_id);
	
	UPDATE "Register" r
	SET final_grade = r.exam_grade,
		register_status = case
							when r.exam_grade>=noLabs.exam_min then 'pass'::register_status_type
							else 'fail'::register_status_type
						  end
		from (select * from "Register" natural join "CourseRun"
				where semesterrunsin = (select semester_id from "Semester"
												where semester_status='present') 
					  and labuses is null) as noLabs

	where noLabs.course_code = r.course_code and noLabs.serial_number = r.serial_number and noLabs.register_status = 'approved'; --Updating grades of classes with no labs
	
	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	
	UPDATE "Register" r
	SET register_status = case
							when r.exam_grade>=withLabs.exam_min and r.lab_grade>=withLabs.lab_min then 'pass'::register_status_type
							else 'fail'::register_status_type
					  	  end,
		
		final_grade = case
							when r.exam_grade>=withLabs.exam_min and r.lab_grade>=withLabs.lab_min then (round((r.exam_grade*withLabs.exam_percentage*0.01)+(r.lab_grade*(1-withLabs.exam_percentage*0.01)),0))
							when r.lab_grade < withLabs.lab_min then 0
							when r.exam_grade < withLabs.exam_min then r.exam_grade
							else null
						  end			  
		
		from (select * from "Register" natural join "CourseRun"
				where semesterrunsin = (select semester_id from "Semester"
												where semester_status='present') 
					  and labuses is not null) as withLabs

	where withLabs.course_code = r.course_code and withLabs.serial_number = r.serial_number and withLabs.register_status = 'approved'; --Updating grades of classes with no labs
	
	
END;

$$;


ALTER FUNCTION public.finalise_grades2_3(sem_id integer) OWNER TO "postgresUser";

--
-- TOC entry 251 (class 1255 OID 16457)
-- Name: find_dependent_courses3_9(character); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.find_dependent_courses3_9(input character) RETURNS TABLE(course character, title character)
    LANGUAGE plpgsql
    AS $$

DECLARE 


BEGIN
    
RETURN QUERY

With Recursive
Anc(a,d) as (
		select main as a, dependent as d from "Course_depends"
		union
		select Anc.a, "Course_depends".dependent as d
		from Anc, "Course_depends"
		where Anc.d="Course_depends".main)




select a, course_title 
from Anc, "Course"
where "Course".course_code=a and Anc.d=input;


END;

$$;


ALTER FUNCTION public.find_dependent_courses3_9(input character) OWNER TO "postgresUser";

--
-- TOC entry 252 (class 1255 OID 16458)
-- Name: find_diplomas3_8(); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.find_diplomas3_8() RETURNS TABLE(dipoma_num integer, sector_title character)
    LANGUAGE plpgsql
    AS $$

DECLARE 
    dipnum record;
	i record;
    cntr integer;
    tmp_sector integer;
BEGIN
    cntr := 0;

    CREATE TEMP TABLE diplomas3_8(
    dipoma_num integer,
    sector_title character
    );

    for dipnum in (select distinct(diploma_num) from "Diploma")
    loop
       cntr := 0;
       tmp_sector := (select labjoins 
                        from "Committee" com join "Professor" prof join "Lab" l join "Sector" sec		
                            on l.sector_code=sec.sector_code
                            on prof.labjoins=l.lab_code
                            on prof.amka=com.prof_amka
                            where diploma_num=dipnum.diploma_num limit 1);
        for i in (select labjoins 
                        from "Committee" com join "Professor" prof join "Lab" l join "Sector" sec		
                            on l.sector_code=sec.sector_code
                            on prof.labjoins=l.lab_code
                            on prof.amka=com.prof_amka
                            where diploma_num= dipnum.diploma_num )
        loop
            if tmp_sector= i.labjoins then 
                cntr := cntr+1;            
            end if;
        end loop;

        if cntr=(select committe_members_no  from "School_Rules"
	                where year = (select academic_year from "Semester"
			  	    where semester_status = 'present')) then
                                            INSERT INTO diplomas3_8
                                            VALUES(dipnum.diploma_num,tmp_sector);
        end if;
        

    end loop; 

    RETURN QUERY 
	SELECT * FROM diplomas3_8;
    DROP TABLE diplomas3_8;

END;

$$;


ALTER FUNCTION public.find_diplomas3_8() OWNER TO "postgresUser";

--
-- TOC entry 253 (class 1255 OID 16459)
-- Name: find_grade_of_studr3_2(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.find_grade_of_studr3_2(type_of_grade character varying, am character varying) RETURNS TABLE(student_amka character varying, course_code character, grade numeric)
    LANGUAGE plpgsql
    AS $$
DECLARE 
BEGIN
 
if type_of_grade = 'exam_grade' then
	return query
	SELECT t2.amka, t1.course_code, t2.exam_grade	--returns the grade of student in the courses he is registered in current semester
	from (SELECT sem.semester_id,sem.semester_status, cr.serial_number, cr.course_code	--returns the courses that are teached in the current semester
					 FROM "Semester" sem, "CourseRun" cr 
					 where sem.semester_id = cr.semesterrunsin and sem.semester_status = 'present'
		) 
	t1 , (select *			--returns the courseRuns that the Student has tried to register
				from "Register" 
				where amka = am) t2
	where(t1.serial_number = t2.serial_number and t1.course_code = t2.course_code);	

elsif type_of_grade = 'final_grade' then
	return query
	SELECT t2.amka, t1.course_code, t2.final_grade	--returns the grade of student in the courses he is registered in current semester
	from (SELECT sem.semester_id,sem.semester_status, cr.serial_number, cr.course_code	--returns the courses that are teached in the current semester
					 FROM "Semester" sem, "CourseRun" cr 
					 where sem.semester_id = cr.semesterrunsin and sem.semester_status = 'present'
		) 
	t1 , (select *			--returns the courseRuns that the Student has tried to register
				from "Register" 
				where amka = am) t2
	where(t1.serial_number = t2.serial_number and t1.course_code = t2.course_code);
elsif type_of_grade = 'lab_grade' then	
	return query
	SELECT t2.amka, t1.course_code, t2.lab_grade	--returns the grade of student in the courses he is registered in current semester
	from (SELECT sem.semester_id,sem.semester_status, cr.serial_number, cr.course_code	--returns the courses that are teached in the current semester
					 FROM "Semester" sem, "CourseRun" cr 
					 where sem.semester_id = cr.semesterrunsin and sem.semester_status = 'present'
		) 
	t1 , (select *			--returns the courseRuns that the Student has tried to register
				from "Register" 
				where amka = am) t2
	where(t1.serial_number = t2.serial_number and t1.course_code = t2.course_code);	
end if;
END;
$$;


ALTER FUNCTION public.find_grade_of_studr3_2(type_of_grade character varying, am character varying) OWNER TO "postgresUser";

--
-- TOC entry 254 (class 1255 OID 16460)
-- Name: find_latest_grade(character varying); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.find_latest_grade(amka_in character varying) RETURNS numeric
    LANGUAGE plpgsql
    AS $$

BEGIN
	RETURN final_grade
	from "Register" r, "CourseRun" cr,"Semester" se
	where  r.course_code=cr.course_code and r.serial_number=cr.serial_number and cr.semesterrunsin = se.semester_id 
		  and se.end_date=(select max(se.end_date) --se.semester_id
							   from "Semester" se
							   where  se.semester_status='past' )  and r.amka = amka_in and r.final_grade is not null 
							   
	order by se.end_date limit 1;
						   
						   
END;

$$;


ALTER FUNCTION public.find_latest_grade(amka_in character varying) OWNER TO "postgresUser";

--
-- TOC entry 255 (class 1255 OID 16461)
-- Name: find_lbmodules_of_stud3_4(character varying); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.find_lbmodules_of_stud3_4(am character varying) RETURNS TABLE(module_number integer, "Participation" text)
    LANGUAGE plpgsql
    AS $$
DECLARE
rec record;
begin
	FOR rec IN	
	(select module_no	--this table contains al the labmodules for the current semester
	 from(
		select c.course_code, c.serial_number, c.semesterrunsin, l.type, l.module_no 
		 from "LabModule" l, "CourseRun" c
		 where(c.course_code = l.course_code and c.serial_number = l."courseRun_ser_num")) t1 
	 where(semesterrunsin = (select semester_id
						     from "Semester"
						     where semester_status = 'present')))
	loop
	return query
	select rec.module_no, case when
		exists (SELECT 1 
				FROM (select module_no from "joins" --this table contains the labmodules that the student has participated over the years
					 where student_amka = am) t 
				WHERE module_no = rec.module_no LIMIT 1)			 
	then 'YES'	else 'NO' 
	end as Participation;
	
	end loop;
	
	
end;
$$;


ALTER FUNCTION public.find_lbmodules_of_stud3_4(am character varying) OWNER TO "postgresUser";

--
-- TOC entry 249 (class 1255 OID 16462)
-- Name: find_max_grades_of_semester3_5(integer, public.semester_season_type, character varying); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.find_max_grades_of_semester3_5(year integer, season public.semester_season_type, type_of_grade character varying) RETURNS TABLE(course character, grade numeric)
    LANGUAGE plpgsql
    AS $$
DECLARE
s_id integer;
begin
s_id:=   (select semester_id			--i find the semester id that corresponds to requested year and season
		from "Semester"
		where academic_year = year and academic_season = season);	



if type_of_grade = 'final_grade' then
	return query
	select course_code, max(final_grade) max_grades 
	from "Register"
	where serial_number = (SELECT  cr.serial_number	
						   --returns the year (serial_number)(i.e. 1st / 2nd/ etc) that corresponds in the courses for the spesific semester that we are looking for  
						   FROM "Semester" sem, "CourseRun" cr 
						   where sem.semester_id = cr.semesterrunsin and  sem.semester_id = s_id
						   LIMIT 1 )	
		AND course_code in(
						   SELECT  cr.course_code	--returns the courses that are teached in the specific semester
						   FROM "Semester" sem, "CourseRun" cr 
						   where sem.semester_id = cr.semesterrunsin and  sem.semester_id = s_id 
						   )
	group by course_code
	order by max_grades desc;
elsif type_of_grade = 'lab_grade' then
	return query
	select course_code, max(lab_grade) max_grades 
	from "Register"
	where serial_number = (SELECT  cr.serial_number
						   FROM "Semester" sem, "CourseRun" cr 
						   where sem.semester_id = cr.semesterrunsin and  sem.semester_id = s_id
						   LIMIT 1 )	
		AND course_code in(
						   SELECT  cr.course_code	
						   FROM "Semester" sem, "CourseRun" cr 
						   where sem.semester_id = cr.semesterrunsin and  sem.semester_id = s_id 
						   )
	group by course_code
	order by max_grades desc;
elsif type_of_grade = 'exam_grade' then
	return query
	select course_code, max(exam_grade) max_grades 
	from "Register"
	where serial_number = (SELECT  cr.serial_number	
						   FROM "Semester" sem, "CourseRun" cr 
						   where sem.semester_id = cr.semesterrunsin and  sem.semester_id = s_id
						   LIMIT 1 )	
		AND course_code in(
						   SELECT  cr.course_code	
						   FROM "Semester" sem, "CourseRun" cr 
						   where sem.semester_id = cr.semesterrunsin and  sem.semester_id = s_id 
						   )
	group by course_code
	order by max_grades desc;
end if;	
end;
$$;


ALTER FUNCTION public.find_max_grades_of_semester3_5(year integer, season public.semester_season_type, type_of_grade character varying) OWNER TO "postgresUser";

--
-- TOC entry 257 (class 1255 OID 16463)
-- Name: find_sector_w_mostdiplomas_3_6(); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.find_sector_w_mostdiplomas_3_6() RETURNS TABLE(sector_titles character)
    LANGUAGE plpgsql
    AS $$

DECLARE 
    max_num_of_refrences integer;
BEGIN
	

max_num_of_refrences:= (select num)
				from (
select sec.sector_title, count(*) as num
						from "Committee" com join "Professor" prof join "Lab" l join "Sector" sec		
						on l.sector_code=sec.sector_code
						on prof.labjoins=l.lab_code
						on prof.amka=com.prof_amka
						where com.supervisor='True' and com.diploma_num in(select diploma_num 
																		   from "Diploma" 
																		   where diploma_grade>=5)
						group by sec.sector_title)"countedSectors"
					WHERE "countedSectors".num >= ALL (select count(*) as num
														from "Committee" com join "Professor" prof join "Lab" l join "Sector" sec		
														on l.sector_code=sec.sector_code
														on prof.labjoins=l.lab_code
														on prof.amka=com.prof_amka
													   	where com.supervisor='True' and com.diploma_num in(select diploma_num 
																		   from "Diploma" 
																		   where diploma_grade>=5)
														group by sec.sector_title);

Return QUERY
select "countedSectors".sector_title
from (select sec.sector_title, count(*) as num
		from "Committee" com join "Professor" prof join "Lab" l join "Sector" sec		
		on l.sector_code=sec.sector_code
		on prof.labjoins=l.lab_code
	  	on prof.amka=com.prof_amka
	  	where com.supervisor='True' and com.diploma_num in(select diploma_num 
																		   from "Diploma" 
																		   where diploma_grade>=5)
		group by sec.sector_title)"countedSectors"
WHERE "countedSectors".num = max_num_of_refrences;

	
-------------------------------------------------------------------------------------	

	
	
END;

$$;


ALTER FUNCTION public.find_sector_w_mostdiplomas_3_6() OWNER TO "postgresUser";

--
-- TOC entry 258 (class 1255 OID 16464)
-- Name: find_teachers_of_lab_sector3_1(integer); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.find_teachers_of_lab_sector3_1(sec_code integer) RETURNS TABLE(amka character varying, name character varying, surname character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE 

BEGIN

return query 
select tf.amka, tf.name, tf.surname
from(
	select t1.amka,t1.name, t1.surname, t2.sector_code
	from	(SELECT pr.amka,pe.name, pe.surname, pr.labjoins
			 FROM "Professor" pr JOIN "Person" pe 
			 USING (amka)) t1, "Lab" t2
	where (t1.labjoins = t2.lab_code)

	union

	select t3.amka,t3.name, t3.surname, t4.sector_code
	from	(SELECT lb.amka,pe.name, pe.surname, lb.labworks
			 FROM "LabTeacher" lb JOIN "Person" pe 
			 USING (amka)) t3, "Lab" t4 
	where (t3.labworks = t4.lab_code)
	)tf
where sector_code = sec_code;

END;
$$;


ALTER FUNCTION public.find_teachers_of_lab_sector3_1(sec_code integer) OWNER TO "postgresUser";

--
-- TOC entry 259 (class 1255 OID 16465)
-- Name: fixsemester(); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.fixsemester() RETURNS void
    LANGUAGE plpgsql
    AS $$
	
begin	

for i in 1..25
loop
UPDATE "Semester"
	SET academic_year = (select date_part('year', start_date) ::integer
           from "Semester" where semester_id=i),
		academic_season = case 
                        when (select date_part('month', start_date)::integer
                               from "Semester" as month
                                where semester_id=i) = 3 then 'spring'::semester_season_type
                        else 'winter'::semester_season_type
                        end
	WHERE semester_id = i;
end loop;		
	
END;
$$;


ALTER FUNCTION public.fixsemester() OWNER TO "postgresUser";

--
-- TOC entry 260 (class 1255 OID 16466)
-- Name: insert_diplomas(); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.insert_diplomas() RETURNS void
    LANGUAGE plpgsql
    AS $$

DECLARE 
    numOfDiplomas int;
	numOfNewAmkas int;
	maxNumOfCommitteeMembers int;
	title character varying;

BEGIN
	
	DROP VIEW "correctAmkas";
	CREATE VIEW  "correctAmkas" AS
	SELECT * FROM(
			SELECT ROW_NUMBER() OVER (ORDER BY (SELECT '1')) AS rowNum
			,*
			from public.createTableA()
			)t2 ;
	
	
	
    numOfDiplomas := (SELECT COUNT(student_am))
		from "Diploma";
		
	numOfNewAmkas := (SELECT COUNT(amka))
		from "correctAmkas";
		
	maxNumOfCommitteeMembers := "School_Rules".committe_members_no 
					from "School_Rules"	
					where "School_Rules".year = (select academic_year 
												   from "Semester"
												   where semester_status = 'present') ;
		
	
	
	for i in 1..numOfNewAmkas
	loop
		INSERT INTO  public."Diploma" (thesis_title, student_am, diploma_num)
		select rndmTitle.title, A.amka,  numOfDiplomas+i
		from (SELECT "DiplomaTitles".title FROM "DiplomaTitles"
					ORDER BY random() LIMIT 1) as rndmTitle
			, (SELECT amka FROM "correctAmkas" where "correctAmkas".rownum=i) as  A
			group by rndmTitle.title, A.amka;
		
		
-----------------Insert diploma info and SUPERVISOR professor in Committe table------------------
		INSERT INTO public."Committee"(supervisor, prof_amka,diploma_num,stud_amka)
		SELECT '1', rndmProf.amka, numOfDiplomas+i, B.student_am
		from (SELECT "Professor".amka FROM "Professor"
					ORDER BY random() LIMIT 1) as rndmProf
			, (SELECT student_am FROM "Diploma" where "Diploma".diploma_num=numOfDiplomas+i) as  B
			group by rndmProf.amka, B.student_am;
-------------------------------------------------------------------------------------------------		
-----------------Insert diploma info and ΝΟΝ-SUPERVISOR professors in Committe table------------------
		for y in 1..(maxNumOfCommitteeMembers-1)
		loop
			INSERT INTO public."Committee"(supervisor, prof_amka,diploma_num,stud_amka)
			SELECT '0', rndmProf.amka, numOfDiplomas+i, B.student_am
			from (SELECT "Professor".amka FROM  "Professor"
						where "Professor".amka NOT IN (SELECT prof_amka 
													   from "Committee" 
													   where diploma_num=numOfDiplomas+i) 
														ORDER BY random() LIMIT 1) as rndmProf
				, (SELECT student_am FROM "Diploma" where "Diploma".diploma_num=numOfDiplomas+i) as  B
				group by rndmProf.amka, B.student_am;
		end loop;
-------------------------------------------------------------------------------------------------		

	end loop;
	
	
	
END;

$$;


ALTER FUNCTION public.insert_diplomas() OWNER TO "postgresUser";

--
-- TOC entry 261 (class 1255 OID 16467)
-- Name: insert_grades(integer); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.insert_grades(sem_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$

DECLARE 
    latestGrade numeric;
	am record;
BEGIN

	UPDATE "Register" r
    SET exam_grade= ( floor(random() * (10-1+1) + 1)::integer)::numeric
	where r.register_status='approved' and r.exam_grade is null and r.serial_number in (select a.serial_number
																					 from ("Semester" s natural join "CourseRun" cr) a
																					 where a.semester_id = sem_id) ;
	
	
	
	for am in 
	(select amka, course_code
	from "Register" r
	where r.register_status='approved' and r.lab_grade is null 
	and r.serial_number in (select a.serial_number from ("Semester" s natural join "CourseRun" cr) a
																		where a.labuses is not null and a.semester_id = sem_id )
	)
	LOOP
	UPDATE "Register" r2
	SET lab_grade= case
					when  public.find_latest_grade(am.amka)::integer >= 5 then public.find_latest_grade(am.amka)
					else (floor(random() * (10-1+1) + 1)::integer)::numeric
				   end
	where r2.amka= am.amka and r2.course_code= am.course_code;

	END LOOP;
	

	
END;

$$;


ALTER FUNCTION public.insert_grades(sem_id integer) OWNER TO "postgresUser";

--
-- TOC entry 262 (class 1255 OID 16468)
-- Name: insert_lab_teachers(character varying, integer); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.insert_lab_teachers(ccode character varying, cserial integer) RETURNS integer
    LANGUAGE sql
    AS $$
WITH rows AS (
insert into "Supports"
select lt.amka, cr.serial_number, cr.course_code
from
"CourseRun" cr join
"LabTeacher" lt on (cr.course_code=ccode and cr.serial_number = cserial and labUses is not null and cr.labuses = lt.labworks)
order by random()
limit random_between(2,4)
returning 1
)
select count(*) from rows;
$$;


ALTER FUNCTION public.insert_lab_teachers(ccode character varying, cserial integer) OWNER TO "postgresUser";

--
-- TOC entry 263 (class 1255 OID 16469)
-- Name: insert_labmodules(); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.insert_labmodules() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE 
    module_no integer;
	perc numeric;
	maxMembers integer;
	title character varying(30);
    tp "LabModule_type";
	rec record;
	i integer := 0;
BEGIN
	FOR rec IN
	(SELECT course_code, serial_number
	FROM "CourseRun"
	WHERE labuses IS NOT null
	--order by random() limit n
	)
	LOOP
		module_no := i+1;
		perc := ((floor(random() * 6 + 2))*10)::numeric;--percentage between 20-70
		maxMembers := floor(random() * 4 + 1)::integer;	--every workgroup has 1-4 students 
   		title := left(md5(random()::character varying), 5);	--random string. 5 characters length
		if i % 2 = 0 then
			tp :=  'project';
		else
			tp := 'lab_excercise';
		end if;
			i := i+1;
		INSERT into "LabModule" values(module_no, perc, maxMembers, title, tp, rec.course_code, rec.serial_number);	
	END LOOP;	
END;
$$;


ALTER FUNCTION public.insert_labmodules() OWNER TO "postgresUser";

--
-- TOC entry 264 (class 1255 OID 16470)
-- Name: insert_professors(character varying, integer); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.insert_professors(ccode character varying, cserial integer) RETURNS integer
    LANGUAGE sql
    AS $$
WITH rows AS (
insert into "Teaches"
select lt.amka, cr.serial_number, cr.course_code
from
"CourseRun" cr join
"Professor" lt on (cr.course_code=ccode and cr.serial_number = cserial 
                   and ((labjoins is not null and cr.labuses = lt.labjoins) or ((select count(*) from "Covers" where lab_code=lt.labjoins and field_code=left(cr.course_code,3))>0)))
order by random()
limit random_between(1,random_between(1,random_between(2,3)))
returning 1
)
select count(*) from rows;
$$;


ALTER FUNCTION public.insert_professors(ccode character varying, cserial integer) OWNER TO "postgresUser";

--
-- TOC entry 265 (class 1255 OID 16471)
-- Name: insert_students(integer); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.insert_students(thousands integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
	FOR i IN 1..thousands LOOP
		with ins_persons as 
		 (
			 insert into "Person"
			 select * from create_persons(1000,10,20)
			 ON CONFLICT (amka) DO NOTHING
			 returning amka
		 ),
		 max_stud as (
			 select left(am,4)::integer as yy, max(right(am,6)::integer)+1 as nextam from
			"Student" 
			group by left(am,4)::integer
		 )
		 insert into "Student"
		 select amka, create_am(yy::integer,p.row+p.nextam), entry_date
		 from
		(select 
		 amka,CONCAT('20',right(left(amka,6),2)) as yy, CONCAT('20',right(left(amka,6),2),'-09-',random_between(1,30))::date as entry_date, ms.nextam, row_number() OVER ()::integer as row
		from 
		ins_persons ip join
		max_stud ms on (ms.yy = CONCAT('20',right(left(ip.amka,6),2))::integer)
		) as p;
	END LOOP;
END;
$$;


ALTER FUNCTION public.insert_students(thousands integer) OWNER TO "postgresUser";

--
-- TOC entry 266 (class 1255 OID 16472)
-- Name: insert_workgroups2_2(integer, integer); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.insert_workgroups2_2(modu_no integer, num_of_groups integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE 
i integer := max("wgID") from "Workgroup";
j integer := 0;
rec record;
am character varying;
BEGIN

IF i IS null THEN
	i := 0;
END IF;	

--find the record for the module_no that we are looking for.
SELECT module_no, course_code, max_members, serial_number
into rec
FROM "LabModule"
WHERE module_no = modu_no;

--Now we insert the students that are approved for registration in this Course and the Course has labModule

FOR am IN
    (SELECT r.amka
    FROM "Register" r, "Course" c 
    WHERE c.course_code = r.course_code AND c.lab_hours >0  AND r.course_code = rec.course_code
    order by random() limit num_of_groups*rec.max_members       --we will assign students to workGroups randomly (We need num_of_groupsrec.max_member students)
    )
	LOOP
		IF j=0 THEN
			i:= i+1;
			INSERT into "Workgroup" ("wgID", course_code, serial_number,module_no)
			values(i, rec.course_code, rec.serial_number, rec.module_no);	
			
		elsif j=rec.max_members THEN
			j:=0;
			continue;
		END IF;
	 	j:= j+1;
		RAISE NOTICE 'course_code(%)',rec.course_code ;
		INSERT into "Joins" (amka, "wgID", course_code, serial_number, module_no)
		values(am, i, rec.course_code, rec.serial_number, rec.module_no);
		-------------------------------------
		
	END LOOP;
END;
$$;


ALTER FUNCTION public.insert_workgroups2_2(modu_no integer, num_of_groups integer) OWNER TO "postgresUser";

--
-- TOC entry 267 (class 1255 OID 16473)
-- Name: next_course_serial(character varying); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.next_course_serial(course_code character varying) RETURNS integer
    LANGUAGE sql
    AS $_$
select COALESCE(MAX(serial_number), 0)+1 
from "CourseRun" where course_code=$1
$_$;


ALTER FUNCTION public.next_course_serial(course_code character varying) OWNER TO "postgresUser";

--
-- TOC entry 268 (class 1255 OID 16474)
-- Name: non_oblig_cour_not_teached3_3(); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.non_oblig_cour_not_teached3_3() RETURNS TABLE(title character, code character)
    LANGUAGE plpgsql
    AS $$
DECLARE 
BEGIN
return query 
select course_code, course_title from "Course"	--find courses that are supposed to be teached in current semester i.e.either it is spring or winter
			where obligatory = false and typical_season = (select academic_season
						   		from "Semester"
						  	 	where semester_status = 'present')
			except
select c.course_code, c.course_title from "Course" c join "CourseRun"	--find non obligatory courses that are teached in current semester
				USING (course_code)
				where obligatory = false and semesterrunsin = (select semester_id
						   										from "Semester"
																where semester_status = 'present');
END;
$$;


ALTER FUNCTION public.non_oblig_cour_not_teached3_3() OWNER TO "postgresUser";

--
-- TOC entry 269 (class 1255 OID 16475)
-- Name: random_amka(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.random_amka(num integer, start_year integer, end_year integer) RETURNS TABLE(amka character varying, id integer)
    LANGUAGE sql
    AS $$
with rdates AS (
	select random_between(start_year,end_year) as y , random_between(1,12) as m ,random_between(1,28) as d
	from generate_series(1,num)
)
select 
CONCAT(lpad(d::text,2,'0'),lpad(m::text,2,'0'),lpad(y::text,2,'0'),'0',rpad(random_between(1,9999)::text,4,'0')),
row_number() OVER ()::integer
from rdates r
$$;


ALTER FUNCTION public.random_amka(num integer, start_year integer, end_year integer) OWNER TO "postgresUser";

--
-- TOC entry 270 (class 1255 OID 16476)
-- Name: random_between(integer, integer); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.random_between(low integer, high integer) RETURNS integer
    LANGUAGE plpgsql STRICT
    AS $$
BEGIN
   RETURN floor(random()* (high-low + 1) + low);
END;
$$;


ALTER FUNCTION public.random_between(low integer, high integer) OWNER TO "postgresUser";

--
-- TOC entry 271 (class 1255 OID 16477)
-- Name: random_lab(); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.random_lab() RETURNS integer
    LANGUAGE sql
    AS $$
(select lab_code from "Lab" order by random() limit 1)
$$;


ALTER FUNCTION public.random_lab() OWNER TO "postgresUser";

--
-- TOC entry 272 (class 1255 OID 16478)
-- Name: random_lab_field(character varying); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.random_lab_field(field character varying) RETURNS integer
    LANGUAGE sql
    AS $$select l.lab_code
from 
"Lab" l join
"Covers" c on (l.lab_code = c.lab_code and c.field_code=field)
order by random()
limit 1$$;


ALTER FUNCTION public.random_lab_field(field character varying) OWNER TO "postgresUser";

--
-- TOC entry 273 (class 1255 OID 16479)
-- Name: random_level(); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.random_level() RETURNS character varying
    LANGUAGE sql
    AS $$
select * 
from  unnest(enum_range(NULL::level_type))
order by random()
limit 1
$$;


ALTER FUNCTION public.random_level() OWNER TO "postgresUser";

--
-- TOC entry 274 (class 1255 OID 16480)
-- Name: random_names(integer); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.random_names(n integer) RETURNS TABLE(name character varying, sex character, id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
RETURN QUERY
SELECT nam.name, nam.sex, row_number() OVER ()::integer
FROM (SELECT "Name".name, "Name".sex
FROM "Name"
ORDER BY random() LIMIT n) as nam;
END;
$$;


ALTER FUNCTION public.random_names(n integer) OWNER TO "postgresUser";

--
-- TOC entry 275 (class 1255 OID 16481)
-- Name: random_rank(); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.random_rank() RETURNS character varying
    LANGUAGE sql
    AS $$select * 
from  unnest(enum_range(NULL::rank_type))
order by random()
limit 1$$;


ALTER FUNCTION public.random_rank() OWNER TO "postgresUser";

--
-- TOC entry 276 (class 1255 OID 16482)
-- Name: random_surnames(integer); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.random_surnames(n integer) RETURNS TABLE(surname character varying, id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
RETURN QUERY
SELECT snam.surname, row_number() OVER ()::integer
FROM (SELECT "Surname".surname
FROM "Surname"
WHERE right("Surname".surname,2)='ΗΣ'
ORDER BY random() LIMIT n) as snam;
END;
$$;


ALTER FUNCTION public.random_surnames(n integer) OWNER TO "postgresUser";

--
-- TOC entry 277 (class 1255 OID 16483)
-- Name: semester_info_insert_5_2(); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.semester_info_insert_5_2() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	
BEGIN
	UPDATE "Semester"
	SET academic_year = (select date_part('year', start_date) ::integer
           from "Semester" where semester_id=NEW.semester_id),
		academic_season = case 
                        when (select date_part('month', start_date)::integer
                               from "Semester" as month
                                where semester_id=NEW.semester_id) = 3 then 'spring'::semester_season_type
                        else 'winter'::semester_season_type
                        end
	WHERE ("Semester".academic_year is null and "Semester".academic_season is null); --insert case
	RETURN NEW;

END;
$$;


ALTER FUNCTION public.semester_info_insert_5_2() OWNER TO "postgresUser";

--
-- TOC entry 278 (class 1255 OID 16484)
-- Name: semester_info_update_5_2(); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.semester_info_update_5_2() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	
BEGIN
	NEW.academic_year=(select date_part('year', NEW.start_date) ::integer );
	NEW.academic_season = case 
                        when (select date_part('month', NEW.start_date)::integer) = 3 then 'spring'::semester_season_type
                        else 'winter'::semester_season_type
                        end;
	RETURN NEW;

END;
$$;


ALTER FUNCTION public.semester_info_update_5_2() OWNER TO "postgresUser";

--
-- TOC entry 256 (class 1255 OID 16485)
-- Name: view_committee_members_for_undergrads6_1(); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.view_committee_members_for_undergrads6_1() RETURNS void
    LANGUAGE plpgsql
    AS $$

BEGIN
	
	CREATE OR REPLACE VIEW  "committee_members" AS
	SELECT * FROM(select p.amka AS "AMKA", (p.name|| ' ' || p.surname) as "Επιτροπή" from "Committee" com join "Professor" prof join "Person" p
		on p.amka=prof.amka
		on com.prof_amka=prof.amka
		where diploma_num in (select diploma_num from "Diploma" d where d.diploma_grade < 5 or d.diploma_grade is null)
			)committee_members ;
	

END;

$$;


ALTER FUNCTION public.view_committee_members_for_undergrads6_1() OWNER TO "postgresUser";

--
-- TOC entry 279 (class 1255 OID 16486)
-- Name: view_multitude_of_undergrads_per_year6_2(); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.view_multitude_of_undergrads_per_year6_2() RETURNS void
    LANGUAGE plpgsql
    AS $$

BEGIN
	
	CREATE OR REPLACE VIEW  "undergrads_per_year6_2" AS
	with data AS(
	with undergrads as(
    select  s.am as am, count(s.am)as numofcourses, sum(units) as totalunits
    from "Student" s natural join "Register" r natural join "Course"
    where r.register_status='pass'
    group by  s.am)
	SELECT * FROM(select distinct(left(s.am,4))::integer as Year , count(s.am) as Multitude
                    from "Student" s 
                    where left(s.am,4)::integer >= (select academic_year-10 from "Semester" where semester_status='present')
                        and s.am in (select am from undergrads u 
									 where numofcourses>=(select min_courses from "School_Rules" where year=(select academic_year from "Semester" where semester_status='present')) 
									 and totalunits>= (select min_units from "School_Rules" where year=(select academic_year from "Semester" where semester_status='present'))
									)
                    group by Year
                    order by Year asc
                )x
	)
	select tmp."Year" as "Year" , coalesce(d.multitude,0) as "Multitude"
	from (select distinct(left(s.am,4))::integer as "Year" , count(distinct(left(s.am,4)))-1 as "Multitude"
			from "Student" s 
			where left(s.am,4)::integer >= (select academic_year-10 from "Semester" where semester_status='present')
			group by "Year"
			order by "Year" asc) as tmp 
			LEFT JOIN data d
			on tmp."Year"=d.year
			order by "Year" asc;			


END;

$$;


ALTER FUNCTION public.view_multitude_of_undergrads_per_year6_2() OWNER TO "postgresUser";

--
-- TOC entry 280 (class 1255 OID 16487)
-- Name: workload_of_labteachers_curr_sem3_7(); Type: FUNCTION; Schema: public; Owner: postgresUser
--

CREATE FUNCTION public.workload_of_labteachers_curr_sem3_7() RETURNS TABLE(labteacher_amka character varying, surnames character varying, names character varying, total_hours bigint)
    LANGUAGE plpgsql
    AS $$
DECLARE 
BEGIN

return query
	select amka, surname, name,  CASE WHEN total_lab_hours IS NULL THEN 0 ELSE total_lab_hours END --AS hours_for_wgIDs	--ypologizei ton forto mono gia tiw omades xwris ta lab_hours
	from
		(select amka, surname, name from "LabTeacher" natural join "Person") lb
	left outer join 
		(select amka, hours +lab_hours as total_lab_hours ----selects the amka and the total lab hours(of Course and hours for wgIDs)
		from 
		(SELECT
				amka,
				count ("wgID") AS hours
			FROM
					(select * --these are course_code, , lab_hours, wgID, serial_number, module_no, amka of lab_teacher for every lab_teacher
				from

					(select t1.course_code, t1.module_no, t2.serial_number, t1."wgID", t2.lab_hours		--ayta einai ta diaforetika workgroups me ta ma8hmata poy aforoyn gia sygkekrimeno examhno
					from
					(select * from "WorkGroup" natural join "LabModule" where type = 'lab_excercise') t1
					join 

					(select course_code, serial_number, lab_hours from
						(select course_code, serial_number  from "CourseRun" where labuses is not null and semesterrunsin =(select semester_id
																															from "Semester"
																															where semester_status = 'present')) l natural join "Course") t2
					on(t1."courseRun_ser_num" = t2.serial_number and t1.course_code = t2.course_code)) t3

					natural join

					(select * from "Supports") t4) tx
			GROUP BY
				amka) sss

		natural join

		(SELECT				--shows amka, sum of lab_hours that a labteacher has in the current semester(due to lab_hours of Course)
				amka,
				sum (lab_hours) AS lab_hours
		from(
		select distinct  course_code, amka, lab_hours --these are  different pairs of course_code, lab_hours, amka of lab_teacher for every lab_teacher
		from

					(select t1.course_code, t1.module_no, t2.serial_number, t1."wgID", t2.lab_hours		--ayta einai ta diaforetika workgroups me ta ma8hmata poy aforoyn gia sygkekrimeno examhno
					from
					(select * from "WorkGroup" natural join "LabModule" where type = 'lab_excercise') t1
						join 

					(select course_code, serial_number, lab_hours from
						(select course_code, serial_number  from "CourseRun" where labuses is not null and semesterrunsin =(select semester_id
																															from "Semester"
																															where semester_status = 'present')) l natural join "Course") t2
					on(t1."courseRun_ser_num" = t2.serial_number and t1.course_code = t2.course_code)) t3

					natural join

					(select * from "Supports") t4
		) z
		GROUP BY
				amka) st) vevw
	using(amka)
	order by total_lab_hours desc;


END;
$$;


ALTER FUNCTION public.workload_of_labteachers_curr_sem3_7() OWNER TO "postgresUser";

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 200 (class 1259 OID 16488)
-- Name: Committee; Type: TABLE; Schema: public; Owner: postgresUser
--

CREATE TABLE public."Committee" (
    supervisor boolean,
    prof_amka character varying NOT NULL,
    diploma_num integer NOT NULL,
    stud_amka character varying NOT NULL
);


ALTER TABLE public."Committee" OWNER TO "postgresUser";

--
-- TOC entry 201 (class 1259 OID 16494)
-- Name: Course; Type: TABLE; Schema: public; Owner: postgresUser
--

CREATE TABLE public."Course" (
    course_code character(7) NOT NULL,
    course_title character(100) NOT NULL,
    units smallint NOT NULL,
    lecture_hours smallint NOT NULL,
    tutorial_hours smallint NOT NULL,
    lab_hours smallint NOT NULL,
    typical_year smallint NOT NULL,
    typical_season public.semester_season_type NOT NULL,
    obligatory boolean NOT NULL,
    course_description character varying
);


ALTER TABLE public."Course" OWNER TO "postgresUser";

--
-- TOC entry 202 (class 1259 OID 16500)
-- Name: CourseRun; Type: TABLE; Schema: public; Owner: postgresUser
--

CREATE TABLE public."CourseRun" (
    course_code character(7) NOT NULL,
    serial_number integer NOT NULL,
    exam_min numeric,
    lab_min numeric,
    exam_percentage numeric,
    labuses integer,
    semesterrunsin integer NOT NULL
);


ALTER TABLE public."CourseRun" OWNER TO "postgresUser";

--
-- TOC entry 203 (class 1259 OID 16506)
-- Name: Course_depends; Type: TABLE; Schema: public; Owner: postgresUser
--

CREATE TABLE public."Course_depends" (
    dependent character(7) NOT NULL,
    main character(7) NOT NULL,
    mode public.course_dependency_mode_type
);


ALTER TABLE public."Course_depends" OWNER TO "postgresUser";

--
-- TOC entry 204 (class 1259 OID 16509)
-- Name: Covers; Type: TABLE; Schema: public; Owner: postgresUser
--

CREATE TABLE public."Covers" (
    lab_code integer NOT NULL,
    field_code character(3) NOT NULL
);


ALTER TABLE public."Covers" OWNER TO "postgresUser";

--
-- TOC entry 205 (class 1259 OID 16512)
-- Name: Diploma; Type: TABLE; Schema: public; Owner: postgresUser
--

CREATE TABLE public."Diploma" (
    thesis_title character(250),
    diploma_grade numeric,
    graduation_date date,
    diploma_num integer NOT NULL,
    thesis_grade numeric,
    student_am character varying NOT NULL
);


ALTER TABLE public."Diploma" OWNER TO "postgresUser";

--
-- TOC entry 206 (class 1259 OID 16518)
-- Name: DiplomaTitles; Type: TABLE; Schema: public; Owner: postgresUser
--

CREATE TABLE public."DiplomaTitles" (
    title character varying
);


ALTER TABLE public."DiplomaTitles" OWNER TO "postgresUser";

--
-- TOC entry 207 (class 1259 OID 16524)
-- Name: Field; Type: TABLE; Schema: public; Owner: postgresUser
--

CREATE TABLE public."Field" (
    code character(3) NOT NULL,
    title character(100) NOT NULL
);


ALTER TABLE public."Field" OWNER TO "postgresUser";

--
-- TOC entry 208 (class 1259 OID 16527)
-- Name: Lab; Type: TABLE; Schema: public; Owner: postgresUser
--

CREATE TABLE public."Lab" (
    lab_code integer NOT NULL,
    sector_code integer NOT NULL,
    lab_title character(100) NOT NULL,
    lab_description character varying,
    profdirects character varying
);


ALTER TABLE public."Lab" OWNER TO "postgresUser";

--
-- TOC entry 209 (class 1259 OID 16533)
-- Name: LabModule; Type: TABLE; Schema: public; Owner: postgresUser
--

CREATE TABLE public."LabModule" (
    module_no integer NOT NULL,
    percentage numeric,
    max_member integer,
    "Title" character varying(30),
    type public."LabModule_type",
    course_code character(7) NOT NULL,
    "courseRun_ser_num" integer NOT NULL
);


ALTER TABLE public."LabModule" OWNER TO "postgresUser";

--
-- TOC entry 210 (class 1259 OID 16539)
-- Name: LabTeacher; Type: TABLE; Schema: public; Owner: postgresUser
--

CREATE TABLE public."LabTeacher" (
    amka character varying NOT NULL,
    labworks integer,
    level public.level_type NOT NULL
);


ALTER TABLE public."LabTeacher" OWNER TO "postgresUser";

--
-- TOC entry 211 (class 1259 OID 16545)
-- Name: Name; Type: TABLE; Schema: public; Owner: postgresUser
--

CREATE TABLE public."Name" (
    name character varying NOT NULL,
    sex character(1) NOT NULL
);


ALTER TABLE public."Name" OWNER TO "postgresUser";

--
-- TOC entry 212 (class 1259 OID 16551)
-- Name: Person; Type: TABLE; Schema: public; Owner: postgresUser
--

CREATE TABLE public."Person" (
    amka character varying NOT NULL,
    name character varying(30) NOT NULL,
    father_name character varying(30) NOT NULL,
    surname character varying(30) NOT NULL,
    email character varying(30)
);


ALTER TABLE public."Person" OWNER TO "postgresUser";

--
-- TOC entry 213 (class 1259 OID 16557)
-- Name: Professor; Type: TABLE; Schema: public; Owner: postgresUser
--

CREATE TABLE public."Professor" (
    amka character varying NOT NULL,
    labjoins integer,
    rank public.rank_type NOT NULL
);


ALTER TABLE public."Professor" OWNER TO "postgresUser";

--
-- TOC entry 214 (class 1259 OID 16563)
-- Name: Register; Type: TABLE; Schema: public; Owner: postgresUser
--

CREATE TABLE public."Register" (
    amka character varying NOT NULL,
    serial_number integer NOT NULL,
    course_code character(7) NOT NULL,
    exam_grade numeric,
    final_grade numeric,
    lab_grade numeric,
    register_status public.register_status_type
);


ALTER TABLE public."Register" OWNER TO "postgresUser";

--
-- TOC entry 215 (class 1259 OID 16569)
-- Name: School_Rules; Type: TABLE; Schema: public; Owner: postgresUser
--

CREATE TABLE public."School_Rules" (
    committe_members_no integer,
    year integer NOT NULL,
    min_units integer,
    min_courses integer
);


ALTER TABLE public."School_Rules" OWNER TO "postgresUser";

--
-- TOC entry 216 (class 1259 OID 16572)
-- Name: Sector; Type: TABLE; Schema: public; Owner: postgresUser
--

CREATE TABLE public."Sector" (
    sector_code integer NOT NULL,
    sector_title character(100) NOT NULL,
    sector_description character varying
);


ALTER TABLE public."Sector" OWNER TO "postgresUser";

--
-- TOC entry 217 (class 1259 OID 16578)
-- Name: Semester; Type: TABLE; Schema: public; Owner: postgresUser
--

CREATE TABLE public."Semester" (
    semester_id integer NOT NULL,
    academic_year integer,
    academic_season public.semester_season_type,
    start_date date,
    end_date date,
    semester_status public.semester_status_type NOT NULL
);


ALTER TABLE public."Semester" OWNER TO "postgresUser";

--
-- TOC entry 218 (class 1259 OID 16581)
-- Name: Student; Type: TABLE; Schema: public; Owner: postgresUser
--

CREATE TABLE public."Student" (
    amka character varying NOT NULL,
    am character(10),
    entry_date date
);


ALTER TABLE public."Student" OWNER TO "postgresUser";

--
-- TOC entry 219 (class 1259 OID 16587)
-- Name: Supports; Type: TABLE; Schema: public; Owner: postgresUser
--

CREATE TABLE public."Supports" (
    amka character varying NOT NULL,
    serial_number integer NOT NULL,
    course_code character(7) NOT NULL
);


ALTER TABLE public."Supports" OWNER TO "postgresUser";

--
-- TOC entry 220 (class 1259 OID 16593)
-- Name: Surname; Type: TABLE; Schema: public; Owner: postgresUser
--

CREATE TABLE public."Surname" (
    surname character varying NOT NULL
);


ALTER TABLE public."Surname" OWNER TO "postgresUser";

--
-- TOC entry 221 (class 1259 OID 16599)
-- Name: Teaches; Type: TABLE; Schema: public; Owner: postgresUser
--

CREATE TABLE public."Teaches" (
    amka character varying NOT NULL,
    serial_number integer NOT NULL,
    course_code character(7) NOT NULL
);


ALTER TABLE public."Teaches" OWNER TO "postgresUser";

--
-- TOC entry 222 (class 1259 OID 16605)
-- Name: WorkGroup; Type: TABLE; Schema: public; Owner: postgresUser
--

CREATE TABLE public."WorkGroup" (
    "wgID" integer NOT NULL,
    course_code character(7) NOT NULL,
    serial_number integer NOT NULL,
    module_no integer NOT NULL,
    grade numeric
);


ALTER TABLE public."WorkGroup" OWNER TO "postgresUser";

--
-- TOC entry 223 (class 1259 OID 16611)
-- Name: committee_members; Type: VIEW; Schema: public; Owner: postgresUser
--

CREATE VIEW public.committee_members AS
 SELECT committee_members."AMKA",
    committee_members."Επιτροπή"
   FROM ( SELECT p.amka AS "AMKA",
            (((p.name)::text || ' '::text) || (p.surname)::text) AS "Επιτροπή"
           FROM (public."Committee" com
             JOIN (public."Professor" prof
             JOIN public."Person" p ON (((p.amka)::text = (prof.amka)::text))) ON (((com.prof_amka)::text = (prof.amka)::text)))
          WHERE (com.diploma_num IN ( SELECT d.diploma_num
                   FROM public."Diploma" d
                  WHERE ((d.diploma_grade < (5)::numeric) OR (d.diploma_grade IS NULL))))) committee_members;


ALTER TABLE public.committee_members OWNER TO "postgresUser";

--
-- TOC entry 224 (class 1259 OID 16616)
-- Name: correctAmkas; Type: VIEW; Schema: public; Owner: postgresUser
--

CREATE VIEW public."correctAmkas" AS
 SELECT t2.rownum,
    t2.amka
   FROM ( SELECT row_number() OVER (ORDER BY ( SELECT '1'::text AS text)) AS rownum,
            createtablea.amka
           FROM public.createtablea() createtablea(amka)) t2;


ALTER TABLE public."correctAmkas" OWNER TO "postgresUser";

--
-- TOC entry 225 (class 1259 OID 16620)
-- Name: joins; Type: TABLE; Schema: public; Owner: postgresUser
--

CREATE TABLE public.joins (
    student_amka character varying NOT NULL,
    "workGroup_id" integer NOT NULL,
    course_code character varying(7) NOT NULL,
    "courseRun_ser_num" integer NOT NULL,
    module_no integer NOT NULL
);


ALTER TABLE public.joins OWNER TO "postgresUser";

--
-- TOC entry 226 (class 1259 OID 16626)
-- Name: undergrads_per_year6_2; Type: VIEW; Schema: public; Owner: postgresUser
--

CREATE VIEW public.undergrads_per_year6_2 AS
 WITH data AS (
         WITH undergrads AS (
                 SELECT s.am,
                    count(s.am) AS numofcourses,
                    sum("Course".units) AS totalunits
                   FROM ((public."Student" s
                     JOIN public."Register" r USING (amka))
                     JOIN public."Course" USING (course_code))
                  WHERE (r.register_status = 'pass'::public.register_status_type)
                  GROUP BY s.am
                )
         SELECT x.year,
            x.multitude
           FROM ( SELECT DISTINCT ("left"((s.am)::text, 4))::integer AS year,
                    count(s.am) AS multitude
                   FROM public."Student" s
                  WHERE ((("left"((s.am)::text, 4))::integer >= ( SELECT ("Semester".academic_year - 10)
                           FROM public."Semester"
                          WHERE ("Semester".semester_status = 'present'::public.semester_status_type))) AND (s.am IN ( SELECT u.am
                           FROM undergrads u
                          WHERE ((u.numofcourses >= ( SELECT "School_Rules".min_courses
                                   FROM public."School_Rules"
                                  WHERE ("School_Rules".year = ( SELECT "Semester".academic_year
   FROM public."Semester"
  WHERE ("Semester".semester_status = 'present'::public.semester_status_type))))) AND (u.totalunits >= ( SELECT "School_Rules".min_units
                                   FROM public."School_Rules"
                                  WHERE ("School_Rules".year = ( SELECT "Semester".academic_year
   FROM public."Semester"
  WHERE ("Semester".semester_status = 'present'::public.semester_status_type)))))))))
                  GROUP BY ("left"((s.am)::text, 4))::integer
                  ORDER BY ("left"((s.am)::text, 4))::integer) x
        )
 SELECT tmp."Year",
    COALESCE(d.multitude, (0)::bigint) AS "Multitude"
   FROM (( SELECT DISTINCT ("left"((s.am)::text, 4))::integer AS "Year",
            (count(DISTINCT "left"((s.am)::text, 4)) - 1) AS "Multitude"
           FROM public."Student" s
          WHERE (("left"((s.am)::text, 4))::integer >= ( SELECT ("Semester".academic_year - 10)
                   FROM public."Semester"
                  WHERE ("Semester".semester_status = 'present'::public.semester_status_type)))
          GROUP BY ("left"((s.am)::text, 4))::integer
          ORDER BY ("left"((s.am)::text, 4))::integer) tmp
     LEFT JOIN data d ON ((tmp."Year" = d.year)))
  ORDER BY tmp."Year";


ALTER TABLE public.undergrads_per_year6_2 OWNER TO "postgresUser";

--
-- TOC entry 3126 (class 2606 OID 16632)
-- Name: Committee Committee_pkey; Type: CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Committee"
    ADD CONSTRAINT "Committee_pkey" PRIMARY KEY (prof_amka, diploma_num, stud_amka);


--
-- TOC entry 3130 (class 2606 OID 16634)
-- Name: CourseRun CourseRun_pkey; Type: CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."CourseRun"
    ADD CONSTRAINT "CourseRun_pkey" PRIMARY KEY (course_code, serial_number);


--
-- TOC entry 3132 (class 2606 OID 16636)
-- Name: Course_depends Course_depends_pkey; Type: CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Course_depends"
    ADD CONSTRAINT "Course_depends_pkey" PRIMARY KEY (dependent, main);


--
-- TOC entry 3128 (class 2606 OID 16638)
-- Name: Course Course_pkey; Type: CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Course"
    ADD CONSTRAINT "Course_pkey" PRIMARY KEY (course_code);


--
-- TOC entry 3140 (class 2606 OID 16640)
-- Name: Diploma Diploma_pkey; Type: CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Diploma"
    ADD CONSTRAINT "Diploma_pkey" PRIMARY KEY (diploma_num, student_am);


--
-- TOC entry 3142 (class 2606 OID 16642)
-- Name: Field Fields_pkey; Type: CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Field"
    ADD CONSTRAINT "Fields_pkey" PRIMARY KEY (code);


--
-- TOC entry 3147 (class 2606 OID 16644)
-- Name: LabModule LabModule_pkey; Type: CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."LabModule"
    ADD CONSTRAINT "LabModule_pkey" PRIMARY KEY ("courseRun_ser_num", course_code, module_no);


--
-- TOC entry 3149 (class 2606 OID 16646)
-- Name: LabTeacher LabStaff_pkey; Type: CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."LabTeacher"
    ADD CONSTRAINT "LabStaff_pkey" PRIMARY KEY (amka);


--
-- TOC entry 3136 (class 2606 OID 16648)
-- Name: Covers Lab_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Covers"
    ADD CONSTRAINT "Lab_fields_pkey" PRIMARY KEY (field_code, lab_code);


--
-- TOC entry 3144 (class 2606 OID 16650)
-- Name: Lab Lab_pkey; Type: CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Lab"
    ADD CONSTRAINT "Lab_pkey" PRIMARY KEY (lab_code);


--
-- TOC entry 3151 (class 2606 OID 16652)
-- Name: Name Names_pkey; Type: CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Name"
    ADD CONSTRAINT "Names_pkey" PRIMARY KEY (name);


--
-- TOC entry 3153 (class 2606 OID 16654)
-- Name: Person Person_pkey; Type: CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Person"
    ADD CONSTRAINT "Person_pkey" PRIMARY KEY (amka);


--
-- TOC entry 3155 (class 2606 OID 16656)
-- Name: Professor Professor_pkey; Type: CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Professor"
    ADD CONSTRAINT "Professor_pkey" PRIMARY KEY (amka);


--
-- TOC entry 3157 (class 2606 OID 16658)
-- Name: Register Register_pkey; Type: CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Register"
    ADD CONSTRAINT "Register_pkey" PRIMARY KEY (course_code, serial_number, amka);


--
-- TOC entry 3159 (class 2606 OID 16660)
-- Name: School_Rules School_Rules_pkey; Type: CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."School_Rules"
    ADD CONSTRAINT "School_Rules_pkey" PRIMARY KEY (year);


--
-- TOC entry 3161 (class 2606 OID 16662)
-- Name: Sector Sector_pkey; Type: CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Sector"
    ADD CONSTRAINT "Sector_pkey" PRIMARY KEY (sector_code);


--
-- TOC entry 3163 (class 2606 OID 16664)
-- Name: Semester Semester_pkey; Type: CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Semester"
    ADD CONSTRAINT "Semester_pkey" PRIMARY KEY (semester_id);


--
-- TOC entry 3165 (class 2606 OID 16666)
-- Name: Student Student_am_key; Type: CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Student"
    ADD CONSTRAINT "Student_am_key" UNIQUE (am);


--
-- TOC entry 3167 (class 2606 OID 16668)
-- Name: Student Student_pkey; Type: CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Student"
    ADD CONSTRAINT "Student_pkey" PRIMARY KEY (amka);


--
-- TOC entry 3169 (class 2606 OID 16670)
-- Name: Supports Supports_pkey; Type: CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Supports"
    ADD CONSTRAINT "Supports_pkey" PRIMARY KEY (amka, serial_number, course_code);


--
-- TOC entry 3171 (class 2606 OID 16672)
-- Name: Surname Surnames_pkey; Type: CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Surname"
    ADD CONSTRAINT "Surnames_pkey" PRIMARY KEY (surname);


--
-- TOC entry 3173 (class 2606 OID 16674)
-- Name: Teaches Teaches_pkey; Type: CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Teaches"
    ADD CONSTRAINT "Teaches_pkey" PRIMARY KEY (amka, serial_number, course_code);


--
-- TOC entry 3175 (class 2606 OID 16676)
-- Name: WorkGroup WorkGroup_pkey; Type: CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."WorkGroup"
    ADD CONSTRAINT "WorkGroup_pkey" PRIMARY KEY ("wgID", course_code, serial_number, module_no);


--
-- TOC entry 3177 (class 2606 OID 16678)
-- Name: joins joins_pkey; Type: CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public.joins
    ADD CONSTRAINT joins_pkey PRIMARY KEY (student_amka, "workGroup_id", course_code, "courseRun_ser_num", module_no);


--
-- TOC entry 3133 (class 1259 OID 16679)
-- Name: fk_course_depends_dependent; Type: INDEX; Schema: public; Owner: postgresUser
--

CREATE INDEX fk_course_depends_dependent ON public."Course_depends" USING btree (dependent);


--
-- TOC entry 3134 (class 1259 OID 16680)
-- Name: fk_course_depends_main; Type: INDEX; Schema: public; Owner: postgresUser
--

CREATE INDEX fk_course_depends_main ON public."Course_depends" USING btree (main);


--
-- TOC entry 3137 (class 1259 OID 16681)
-- Name: fk_lab_field_lab_code; Type: INDEX; Schema: public; Owner: postgresUser
--

CREATE INDEX fk_lab_field_lab_code ON public."Covers" USING btree (lab_code);


--
-- TOC entry 3138 (class 1259 OID 16682)
-- Name: fk_lab_fields_field_code; Type: INDEX; Schema: public; Owner: postgresUser
--

CREATE INDEX fk_lab_fields_field_code ON public."Covers" USING btree (field_code);


--
-- TOC entry 3145 (class 1259 OID 16683)
-- Name: fk_lab_sector_code; Type: INDEX; Schema: public; Owner: postgresUser
--

CREATE INDEX fk_lab_sector_code ON public."Lab" USING btree (sector_code);


--
-- TOC entry 3207 (class 2620 OID 16684)
-- Name: Register calculate_final_grades; Type: TRIGGER; Schema: public; Owner: postgresUser
--

CREATE TRIGGER calculate_final_grades BEFORE UPDATE ON public."Register" FOR EACH ROW EXECUTE FUNCTION public.calculate_final_grade5_3();


--
-- TOC entry 3210 (class 2620 OID 16685)
-- Name: Semester calculate_year_and_season_insert; Type: TRIGGER; Schema: public; Owner: postgresUser
--

CREATE TRIGGER calculate_year_and_season_insert AFTER INSERT ON public."Semester" FOR EACH ROW EXECUTE FUNCTION public.semester_info_insert_5_2();


--
-- TOC entry 3209 (class 2620 OID 16686)
-- Name: Semester calculate_year_and_season_update; Type: TRIGGER; Schema: public; Owner: postgresUser
--

CREATE TRIGGER calculate_year_and_season_update BEFORE UPDATE ON public."Semester" FOR EACH ROW WHEN ((new.start_date <> old.start_date)) EXECUTE FUNCTION public.semester_info_update_5_2();


--
-- TOC entry 3205 (class 2620 OID 16687)
-- Name: Committee check_insert_committee5_1; Type: TRIGGER; Schema: public; Owner: postgresUser
--

CREATE TRIGGER check_insert_committee5_1 BEFORE INSERT ON public."Committee" FOR EACH ROW EXECUTE FUNCTION public.check_max_committee_members5_1();


--
-- TOC entry 3206 (class 2620 OID 16688)
-- Name: Register check_insert_register5_4; Type: TRIGGER; Schema: public; Owner: postgresUser
--

CREATE TRIGGER check_insert_register5_4 BEFORE UPDATE ON public."Register" FOR EACH ROW EXECUTE FUNCTION public.check_register_criterions5_4();


--
-- TOC entry 3211 (class 2620 OID 16689)
-- Name: joins check_insert_workgroup5_1; Type: TRIGGER; Schema: public; Owner: postgresUser
--

CREATE TRIGGER check_insert_workgroup5_1 BEFORE INSERT ON public.joins FOR EACH ROW EXECUTE FUNCTION public.check_max_workgroup_members5_1();


--
-- TOC entry 3208 (class 2620 OID 16690)
-- Name: Semester create_future_courseruns; Type: TRIGGER; Schema: public; Owner: postgresUser
--

CREATE TRIGGER create_future_courseruns AFTER INSERT ON public."Semester" FOR EACH ROW WHEN ((new.semester_status = 'future'::public.semester_status_type)) EXECUTE FUNCTION public.create_future_courseruns5_5();


--
-- TOC entry 3178 (class 2606 OID 16691)
-- Name: Committee Committe_prof_amka_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Committee"
    ADD CONSTRAINT "Committe_prof_amka_fkey" FOREIGN KEY (prof_amka) REFERENCES public."Professor"(amka) ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


--
-- TOC entry 3179 (class 2606 OID 16696)
-- Name: Committee Committee_Diploma_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Committee"
    ADD CONSTRAINT "Committee_Diploma_fkey" FOREIGN KEY (diploma_num, stud_amka) REFERENCES public."Diploma"(diploma_num, student_am) ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


--
-- TOC entry 3180 (class 2606 OID 16701)
-- Name: CourseRun CourseRun_course_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."CourseRun"
    ADD CONSTRAINT "CourseRun_course_code_fkey" FOREIGN KEY (course_code) REFERENCES public."Course"(course_code);


--
-- TOC entry 3181 (class 2606 OID 16706)
-- Name: CourseRun CourseRun_labuses_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."CourseRun"
    ADD CONSTRAINT "CourseRun_labuses_fkey" FOREIGN KEY (labuses) REFERENCES public."Lab"(lab_code);


--
-- TOC entry 3182 (class 2606 OID 16711)
-- Name: CourseRun CourseRun_semesterrunsin_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."CourseRun"
    ADD CONSTRAINT "CourseRun_semesterrunsin_fkey" FOREIGN KEY (semesterrunsin) REFERENCES public."Semester"(semester_id);


--
-- TOC entry 3187 (class 2606 OID 16716)
-- Name: Diploma Diploma_student_amka_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Diploma"
    ADD CONSTRAINT "Diploma_student_amka_fkey" FOREIGN KEY (student_am) REFERENCES public."Student"(amka) ON UPDATE CASCADE ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3190 (class 2606 OID 16721)
-- Name: LabModule LabModule_courseRun_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."LabModule"
    ADD CONSTRAINT "LabModule_courseRun_fkey" FOREIGN KEY ("courseRun_ser_num", course_code) REFERENCES public."CourseRun"(serial_number, course_code) ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


--
-- TOC entry 3191 (class 2606 OID 16726)
-- Name: LabTeacher LabStaff_labworks_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."LabTeacher"
    ADD CONSTRAINT "LabStaff_labworks_fkey" FOREIGN KEY (labworks) REFERENCES public."Lab"(lab_code);


--
-- TOC entry 3185 (class 2606 OID 16731)
-- Name: Covers Lab_fields_field_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Covers"
    ADD CONSTRAINT "Lab_fields_field_code_fkey" FOREIGN KEY (field_code) REFERENCES public."Field"(code) MATCH FULL NOT VALID;


--
-- TOC entry 3186 (class 2606 OID 16736)
-- Name: Covers Lab_fields_lab_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Covers"
    ADD CONSTRAINT "Lab_fields_lab_code_fkey" FOREIGN KEY (lab_code) REFERENCES public."Lab"(lab_code) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


--
-- TOC entry 3188 (class 2606 OID 16741)
-- Name: Lab Lab_professor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Lab"
    ADD CONSTRAINT "Lab_professor_fkey" FOREIGN KEY (profdirects) REFERENCES public."Professor"(amka) ON UPDATE CASCADE ON DELETE SET NULL NOT VALID;


--
-- TOC entry 3189 (class 2606 OID 16746)
-- Name: Lab Lab_sector_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Lab"
    ADD CONSTRAINT "Lab_sector_code_fkey" FOREIGN KEY (sector_code) REFERENCES public."Sector"(sector_code) MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


--
-- TOC entry 3193 (class 2606 OID 16751)
-- Name: Professor Professor_labJoins_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Professor"
    ADD CONSTRAINT "Professor_labJoins_fkey" FOREIGN KEY (labjoins) REFERENCES public."Lab"(lab_code);


--
-- TOC entry 3194 (class 2606 OID 16756)
-- Name: Professor Professor_person_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Professor"
    ADD CONSTRAINT "Professor_person_fkey" FOREIGN KEY (amka) REFERENCES public."Person"(amka) ON UPDATE RESTRICT ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3195 (class 2606 OID 16761)
-- Name: Register Register_course_run_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Register"
    ADD CONSTRAINT "Register_course_run_fkey" FOREIGN KEY (course_code, serial_number) REFERENCES public."CourseRun"(course_code, serial_number) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3196 (class 2606 OID 16766)
-- Name: Register Register_student_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Register"
    ADD CONSTRAINT "Register_student_fkey" FOREIGN KEY (amka) REFERENCES public."Student"(amka) ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


--
-- TOC entry 3198 (class 2606 OID 16771)
-- Name: Supports Supports_course_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Supports"
    ADD CONSTRAINT "Supports_course_code_fkey" FOREIGN KEY (course_code, serial_number) REFERENCES public."CourseRun"(course_code, serial_number);


--
-- TOC entry 3199 (class 2606 OID 16776)
-- Name: Supports Supports_labteacher_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Supports"
    ADD CONSTRAINT "Supports_labteacher_fkey" FOREIGN KEY (amka) REFERENCES public."LabTeacher"(amka) NOT VALID;


--
-- TOC entry 3200 (class 2606 OID 16781)
-- Name: Teaches Teaches_course_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Teaches"
    ADD CONSTRAINT "Teaches_course_code_fkey" FOREIGN KEY (serial_number, course_code) REFERENCES public."CourseRun"(serial_number, course_code) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3201 (class 2606 OID 16786)
-- Name: Teaches Teaches_professor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Teaches"
    ADD CONSTRAINT "Teaches_professor_fkey" FOREIGN KEY (amka) REFERENCES public."Professor"(amka) ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


--
-- TOC entry 3202 (class 2606 OID 16791)
-- Name: WorkGroup WorkGroup_LabModule_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."WorkGroup"
    ADD CONSTRAINT "WorkGroup_LabModule_fkey" FOREIGN KEY (module_no, serial_number, course_code) REFERENCES public."LabModule"(module_no, "courseRun_ser_num", course_code) ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


--
-- TOC entry 3183 (class 2606 OID 16796)
-- Name: Course_depends dependent; Type: FK CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Course_depends"
    ADD CONSTRAINT dependent FOREIGN KEY (dependent) REFERENCES public."Course"(course_code) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3203 (class 2606 OID 16801)
-- Name: joins joins_Workgroup_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public.joins
    ADD CONSTRAINT "joins_Workgroup_fkey" FOREIGN KEY (course_code, "workGroup_id", module_no, "courseRun_ser_num") REFERENCES public."WorkGroup"(course_code, "wgID", module_no, serial_number) ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


--
-- TOC entry 3204 (class 2606 OID 16806)
-- Name: joins joins_student_am_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public.joins
    ADD CONSTRAINT joins_student_am_fkey FOREIGN KEY (student_amka) REFERENCES public."Student"(amka) ON UPDATE CASCADE ON DELETE CASCADE NOT VALID;


--
-- TOC entry 3192 (class 2606 OID 16811)
-- Name: LabTeacher labStaff_person_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."LabTeacher"
    ADD CONSTRAINT "labStaff_person_fkey" FOREIGN KEY (amka) REFERENCES public."Person"(amka) ON UPDATE RESTRICT ON DELETE RESTRICT NOT VALID;


--
-- TOC entry 3184 (class 2606 OID 16816)
-- Name: Course_depends main; Type: FK CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Course_depends"
    ADD CONSTRAINT main FOREIGN KEY (main) REFERENCES public."Course"(course_code) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 3197 (class 2606 OID 16821)
-- Name: Student student_fkey1; Type: FK CONSTRAINT; Schema: public; Owner: postgresUser
--

ALTER TABLE ONLY public."Student"
    ADD CONSTRAINT student_fkey1 FOREIGN KEY (amka) REFERENCES public."Person"(amka) ON UPDATE RESTRICT ON DELETE RESTRICT NOT VALID;


-- Completed on 2026-05-31 16:40:59 UTC

--
-- PostgreSQL database dump complete
--

\unrestrict T3Tydlfqo2LSG45fRfdghpBC8JK1JztkReAVwvhh7gfIsu7ZmQAtIYcLk4UAhtf

