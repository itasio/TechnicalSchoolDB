package dbms_project_2022;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
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
		String url = "jdbc:postgresql://" + ip + ":5432/" + dbName;
		try {
			conn = DriverManager.getConnection(url, username, password);
			System.out.println("Connection is successful.");
		} catch (SQLException e) {
			System.err.println("Could not connect to database.");
			e.printStackTrace();
		}
	}
	
	public void dbClose() {

		if (conn == null) {
			return;
		}

		try {
			if (!conn.isClosed()) {
				conn.close();
			}
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

		if (conn == null) {
			System.err.println("No database connection.");
			return;
		}

		String personSql =
				"SELECT amka, surname, name " +
						"FROM \"Person\" " +
						"WHERE amka = ?";

		String gradesSql =
				"SELECT y.course_code, l.\"Title\", y.grade " +
						"FROM \"LabModule\" l " +
						"JOIN " +
						"( " +
						"    SELECT w.grade, x.course_code, x.module_no " +
						"    FROM \"WorkGroup\" w " +
						"    JOIN " +
						"    ( " +
						"        SELECT t1.course_code, " +
						"               t1.module_no, " +
						"               t1.\"workGroup_id\" " +
						"        FROM " +
						"        ( " +
						"            SELECT * " +
						"            FROM \"joins\" " +
						"            WHERE student_amka = ? " +
						"        ) t1 " +
						"        JOIN " +
						"        ( " +
						"            SELECT * " +
						"            FROM \"CourseRun\" " +
						"            WHERE semesterrunsin = " +
						"            ( " +
						"                SELECT semester_id " +
						"                FROM \"Semester\" " +
						"                WHERE academic_year = ? " +
						"                  AND academic_season = ? " +
						"            ) " +
						"        ) t2 " +
						"        ON t1.\"courseRun_ser_num\" = t2.serial_number " +
						"        AND t1.course_code = t2.course_code " +
						"    ) x " +
						"    ON w.\"wgID\" = x.\"workGroup_id\" " +
						") y " +
						"USING(module_no)";

		/*
		 * First query:
		 * Retrieve the student's personal information.
		 */
		try (PreparedStatement pst = conn.prepareStatement(personSql)) {

			pst.setString(1, amka);

			try (ResultSet res = pst.executeQuery()) {

				System.out.println();

				while (res.next()) {
					System.out.println(
							"AMKA: " + res.getString("amka") +
									"\nSurname: " + res.getString("surname") +
									"\nName: " + res.getString("name")
					);
				}
			}

		} catch (SQLException e) {
			e.printStackTrace();
			return;
		}

		/*
		 * Second query:
		 * Retrieve the LabModule grades.
		 */
		try (PreparedStatement pst = conn.prepareStatement(gradesSql)) {

			pst.setString(1, amka);
			pst.setInt(2, year);
			pst.setString(3, semester);

			try (ResultSet res = pst.executeQuery()) {

				System.out.println();
				System.out.println("Course_code\tTitle\tGrade");

				while (res.next()) {
					System.out.println(
							res.getString(1) + "\t\t" +
									res.getString(2) + "\t" +
									res.getString(3)
					);
				}
			}

		} catch (SQLException e) {
			e.printStackTrace();
		}
	}

	/**
	 * Inserts random LabModules and their WorkGroups for a CourseRun.
	 */
	public void insert_Labmodules_workGroups(String courseCode, int sernum, int numOfModules, int numOfGroups) {

		if (conn == null) {
			System.err.println("No database connection.");
			return;
		}

		Random rand = new Random();

		int minMember = 2;
		int maxMember = 6;

		String insertLabModuleSql =
				"INSERT INTO \"LabModule\" " +
						"VALUES (" +
						"    ?, " +
						"    ?, " +
						"    (SELECT max(module_no) + 1 FROM \"LabModule\"), " +
						"    ?::labmodule_type, " +
						"    left(md5(random()::character varying), 5), " +
						"    ?, " +
						"    (((floor(random() * 6 + 2)) * 10)::smallint)" +
						")";

		String updateWorkgroupSql =
				"UPDATE \"Workgroup\" " +
						"SET grade = ? " +
						"WHERE \"wgID\" = ?";

		String maxModuleSql =
				"SELECT max(module_no) " +
						"FROM \"LabModule\"";

		String workgroupIdsSql =
				"SELECT \"wgID\" " +
						"FROM \"Workgroup\" " +
						"WHERE module_no = (" +
						"    SELECT max(module_no) " +
						"    FROM \"Workgroup\"" +
						")";

		try (
				PreparedStatement insertLabModule =
						conn.prepareStatement(insertLabModuleSql);

				PreparedStatement updateWorkgroup =
						conn.prepareStatement(updateWorkgroupSql);

				PreparedStatement getMaxModule =
						conn.prepareStatement(maxModuleSql);

				PreparedStatement getWorkgroupIds =
						conn.prepareStatement(workgroupIdsSql);

				CallableStatement insertWorkgroups =
						conn.prepareCall("{call insert_workgroups2_2(?,?)}")
		) {

			for (int i = 0; i < numOfModules; i++) {

				insertLabModule.setString(1, courseCode);
				insertLabModule.setInt(2, sernum);

				double d = rand.nextDouble();

				if (d <= 0.2) {
					insertLabModule.setString(3, "project");
				} else {
					insertLabModule.setString(3, "lab_exercise");
				}

				int numberOfMembers =
						rand.nextInt(maxMember - minMember) + minMember;

				insertLabModule.setInt(4, numberOfMembers);

				insertLabModule.executeUpdate();
				int moduleNo;

				try (ResultSet res = getMaxModule.executeQuery()) {

					if (!res.next()) {
						throw new SQLException(
								"Could not retrieve module number."
						);
					}

					moduleNo = res.getInt(1);
				}

				/*
				 * Create WorkGroups using the stored procedure.
				 */
				insertWorkgroups.setInt(1, moduleNo);
				insertWorkgroups.setInt(2, numOfGroups);

				insertWorkgroups.execute();

				/*
				 * Retrieve WorkGroup IDs and assign random grades.
				 */
				try (ResultSet wgIDs = getWorkgroupIds.executeQuery()) {

					while (wgIDs.next()) {

						int grade =
								(int) Math.round(
										rand.nextGaussian() * 2 + 6
								);

						updateWorkgroup.setInt(1, grade);
						updateWorkgroup.setInt(2, wgIDs.getInt("wgID"));

						updateWorkgroup.executeUpdate();
					}
				}
			}

		} catch (SQLException e) {
			e.printStackTrace();
		}
	}

	/**
	 * Inserts random LabModules/WorkGroups for every CourseRun
	 * whose course code starts with courseMaterial.
	 */
	public void insert_random_Labmodules_workGroups(String courseMaterial, int numOfModules, int numOfGroups) {

		if (conn == null) {
			System.err.println("No database connection.");
			return;
		}

		String sql =
				"SELECT course_code, serial_number " +
						"FROM \"CourseRun\" " +
						"WHERE substring(course_code, 1, 3) = ?";

		try (PreparedStatement pst = conn.prepareStatement(sql)) {
			pst.setString(1, courseMaterial);

			try (ResultSet res = pst.executeQuery()) {

				while (res.next()) {

					String courseCode =
							res.getString("course_code");

					int serialNumber =
							res.getInt("serial_number");

					insert_Labmodules_workGroups(courseCode, serialNumber, numOfModules, numOfGroups);
				}
			}

		} catch (SQLException e) {
			e.printStackTrace();
		}
	}

	public static void main(String[] args) {

		DbApp app = new DbApp();
		String username = System.getenv("DB_USER") != null ? System.getenv("DB_USER") : "postgresUser";
		String password = System.getenv("DB_PASSWORD") != null ? System.getenv("DB_PASSWORD") : "mypassword";

		try {
			app.dbConnect("localhost", "TechnicalSchoolDB", username, password);

			System.out.println("Starting inserts...");
			app.insert_random_Labmodules_workGroups("HRY", 200, 5);
			System.out.println("FINISHED HRY...");

			app.insert_random_Labmodules_workGroups("SYS", 200, 5);
			System.out.println("FINISHED SYS...");

			app.insert_random_Labmodules_workGroups("ENE", 200, 5);
			System.out.println("FINISHED ENE...");

			System.out.println("DONE!!!");
		} finally {
			app.dbClose();
		}
	}
}