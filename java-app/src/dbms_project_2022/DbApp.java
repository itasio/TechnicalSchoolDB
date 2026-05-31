package dbms_project_2022;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.Random;

public class DbApp {

	Connection conn;
	
	public DbApp() {
		try {
			Class.forName("org.postgresql.Driver");
			System.out.println("Driver found.");
		} catch (ClassNotFoundException e) {
			System.out.println("Driver not found. Check buildpath.");
		}
	}
	
	public void dbConnect(String ip, String dbName, String username, String password) {
		try {
			conn = DriverManager.getConnection("jdbc:postgresql://"+ip+":5432/"+dbName, username, password);
			System.out.println("Connection is successful conn:"+conn);
		} catch (SQLException e) {
			e.printStackTrace();
		}
	}
	
	public void dbClose() {
		try {
			conn.close();
		} catch (SQLException e) {
			e.printStackTrace();
		}
		
	}
	
	/**
	 * 
	 * shows the grades of LabModules of a student for a specific semester 
	 * @param   amka the amka of the student
	 * @param   year the academic year of the LabModules
	 * @param   semester the academic semester of the LabModules
	 */
	public void showLabgrades(String amka, int year, String semester) {
		try {
			Statement st = conn.createStatement();
			
			//ResultSet res1 = st.executeQuery("select amka, surname, name from \"Person\" where amka = '11120003960'");
			ResultSet res1 = st.executeQuery("select amka, surname, name from \"Person\" where amka = "+amka);
			System.out.println("");
			
			while (res1.next()) {
				System.out.println("AMKA:"+" "+res1.getString(1)+"\n"+"Surname:"+" "+res1.getString(2)+"\n"+"Name:"+" "+res1.getString(3));
				
			}
			
			res1 = st.executeQuery("select y.course_code, l.\"Title\", y.grade			--course_code, title, grade of the LabModules that the student attends in specific semester\r\n"
					+ "from \"LabModule\" l\r\n"
					+ "join\r\n"
					+ "\r\n"
					+ "	(select w.grade, x.course_code, x.module_no			--grade, course_code, module_no of the LabModules that the student attends in specific semester\r\n"
					+ "	from \"WorkGroup\" w\r\n"
					+ "	join \r\n"
					+ "\r\n"
					+ "		 (select t1.course_code, t1.module_no, t1.\"workGroup_id\"			--course_code, module_no and wgId that the student attends in specific semester\r\n"
					+ "		  from (select * from \"joins\" where student_amka = "+amka+") t1	--labModules that the student attends\r\n"
					+ "		  join\r\n"
					+ "			(select * 													--courses that that are teached in a specific semester and year\r\n"
					+ "			 from \"CourseRun\" \r\n"
					+ "			 where semesterrunsin = ( select semester_id as sid from \"Semester\" where academic_year ="+year+" and academic_season = "+semester+"))t2\r\n"
					+ "		  on (t1.\"courseRun_ser_num\" = t2.serial_number and t1.course_code = t2.course_code)) x\r\n"
					+ "\r\n"
					+ "	on(w.\"wgID\" = x.\"workGroup_id\")) y\r\n"
					+ "using(module_no)");
			
			System.out.println("");
			System.out.println("Course_code"+"\t"+"Title"+"\t"+"Grade");
			
			while (res1.next()) {
				System.out.println(res1.getString(1)+"\t"+"\t"+res1.getString(2)+"\t"+res1.getString(3));
				
			}
			
			res1.close();
			
		} catch (SQLException e) {
			e.printStackTrace();
		}
		
		
	}
	
	public void insert_Labmodules_workGroups(String courseCode, int sernum, int numOfModules,int numOfGroups ) {
		Random rand = new Random();
		int minMember = 2;
		int maxMember = 6;
		try {
			//PST FOR OUR DATABASE FROM PHASE A
			//PreparedStatement pst = conn.prepareStatement("insert into \"LabModule\" values("
				//											+ "(select max(module_no)+1 from \"LabModule\"),"
				//											+" (((floor(random() * 6 + 2))*10)::numeric), ?, (left(md5(random()::character varying), 5)),'project'::labmodule_type,"+courseCode +", "+sernum+")");
			PreparedStatement pst = conn.prepareStatement("insert into \"LabModule\" values("
																+ courseCode+", "+sernum+", (select max(module_no)+1 from \"LabModule\"), ?::labmodule_type, (left(md5(random()::character varying), 5)), ?, (((floor(random() * 6 + 2))*10)::smallint))");
				
		
			
			
			PreparedStatement pst2 = conn.prepareStatement("update \"Workgroup\"\r\n"
														 + "set grade= ?\r\n"
														 + "where\"wgID\"= ?");
			
			CallableStatement cst = conn.prepareCall("{call insert_workgroups2_2(?,?)}");
			
			Statement st = conn.createStatement();
			Statement st2 = conn.createStatement();
			for(int i = 0; i < numOfModules; i++) {				
				////////////////////////////////////////////
				pst.setInt(2, rand.nextInt(maxMember-minMember) + minMember);
				double d = rand.nextDouble();
				if(d <= 0.2)
					pst.setString(1, "project");
				else
					pst.setString(1, "lab_exercise");
				pst.executeUpdate();
				/////////////////////////////////////////////
				ResultSet res1 = st.executeQuery("select max(module_no) from \"LabModule\"");//subqueries not allowed in CallableStatement
				res1.next();
				cst.setInt(2,numOfGroups);
				//System.out.println(res1.getInt(1));
				cst.setInt(1,res1.getInt(1));
				cst.execute();
				
				////////////////////////////////////////////
				ResultSet wgIDs= st2.executeQuery("select \"wgID\" from  \"Workgroup\" where module_no=(select max(module_no) from \"Workgroup\")");
				while(wgIDs.next()) {
				pst2.setInt(1,(int) Math.round(rand.nextGaussian()*2+6));
				pst2.setInt(2,wgIDs.getInt(1));
				pst2.executeUpdate();
				}
				res1.close();
				wgIDs.close();
			}
			pst.close();
			cst.close();
			
		
		} catch (SQLException e) {
			e.printStackTrace();
		}
		
	}
	
	
	
	public void 	insert_random_Labmodules_workGroups(String courseMaterial, int numOfModules,int numOfGroups ) {
		try {
			Statement st = conn.createStatement();
			ResultSet res1 = st.executeQuery("select course_code, serial_number from \"CourseRun\" c  where substring(c.course_code,1,3) ="+courseMaterial+" \r\n");
			
			while(res1.next()) {
				//System.out.println(res1.getString(1)+"\t"+"\t"+res1.getInt(2)+"\t");
				insert_Labmodules_workGroups(("'"+res1.getString(1)+"'"), res1.getInt(2), numOfModules,numOfGroups );

			}			
			res1.close();
		} catch (SQLException e) {
			e.printStackTrace();
		}
		
	}
	
	
	public static void main(String[] args) {
 
		DbApp app = new DbApp();
		app.dbConnect("localhost", "TechnicalSchoolDB", "postgresUser", "mypassword");
		
		System.out.println("Starting inserts...");
		app.insert_random_Labmodules_workGroups("'гяу'", 200, 5);	//252 HRY
		System.out.println("FINISHED HRY...");
		app.insert_random_Labmodules_workGroups("'сус'", 200, 5);	//120 SYS
		System.out.println("FINISHED SYS...");
		app.insert_random_Labmodules_workGroups("'еме'", 200, 5);	//72 еме
		System.out.println("FINISHED ENE...");
		System.out.println("DONE!!!");
		app.dbClose();
		
		app.dbClose();
	}


}



