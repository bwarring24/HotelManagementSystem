USE [master]
GO
/****** Object:  Database [GuestBook]    Script Date: 4/19/2017 7:44:44 PM ******/
CREATE DATABASE [GuestBook]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'GuestBook', FILENAME = N'c:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVERPROD\MSSQL\DATA\GuestBook.mdf' , SIZE = 40960KB , MAXSIZE = UNLIMITED, FILEGROWTH = 1024KB )
 LOG ON 
( NAME = N'GuestBook_log', FILENAME = N'c:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVERPROD\MSSQL\DATA\GuestBook_log.ldf' , SIZE = 10240KB , MAXSIZE = 2048GB , FILEGROWTH = 10%)
GO
ALTER DATABASE [GuestBook] SET COMPATIBILITY_LEVEL = 110
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [GuestBook].[dbo].[sp_fulltext_database] @action = 'enable'
end
GO
ALTER DATABASE [GuestBook] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [GuestBook] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [GuestBook] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [GuestBook] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [GuestBook] SET ARITHABORT OFF 
GO
ALTER DATABASE [GuestBook] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [GuestBook] SET AUTO_CREATE_STATISTICS ON 
GO
ALTER DATABASE [GuestBook] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [GuestBook] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [GuestBook] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [GuestBook] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [GuestBook] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [GuestBook] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [GuestBook] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [GuestBook] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [GuestBook] SET  DISABLE_BROKER 
GO
ALTER DATABASE [GuestBook] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [GuestBook] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [GuestBook] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [GuestBook] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [GuestBook] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [GuestBook] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [GuestBook] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [GuestBook] SET RECOVERY SIMPLE 
GO
ALTER DATABASE [GuestBook] SET  MULTI_USER 
GO
ALTER DATABASE [GuestBook] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [GuestBook] SET DB_CHAINING OFF 
GO
ALTER DATABASE [GuestBook] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO
ALTER DATABASE [GuestBook] SET TARGET_RECOVERY_TIME = 0 SECONDS 
GO
USE [GuestBook]
GO
/****** Object:  UserDefinedTableType [dbo].[RoomToReserve]    Script Date: 4/19/2017 7:44:45 PM ******/
CREATE TYPE [dbo].[RoomToReserve] AS TABLE(
	[room_type] [varchar](50) NULL,
	[number_of_rooms] [tinyint] NULL
)
GO
/****** Object:  StoredProcedure [dbo].[spAddEmployee]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spAddEmployee](
	@first_name	VARCHAR(50),
	@last_name VARCHAR(50),
	@email	VARCHAR(255),
	@phone_number	CHAR(10),
	@password_hash	VARCHAR(MAX),
	@salt	VARCHAR(255),
	@access_level TINYINT)
AS
BEGIN

	INSERT INTO [Employee]
	(
		first_name,
		last_name,
		email,
		phone_number,
		password_hash,
		salt,
		access_level
	)
	VALUES
	(
		@first_name,
		@last_name,
		@email,
		@phone_number,
		@password_hash,
		@salt,
		@access_level
	)

END



GO
/****** Object:  StoredProcedure [dbo].[spAddPermissionForEmployee]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spAddPermissionForEmployee](@employee_id AS INT, 
                                        @permission_name  AS VARCHAR(50), 
                                        @priority    AS TINYINT) 
AS 
  BEGIN 
      DECLARE @ERR_MSG AS NVARCHAR(1000), 
              @ERR_STA AS SMALLINT 

      BEGIN try 
          IF ( ( @employee_id IS NULL 
                  OR @employee_id = '' ) 
                OR ( @permission_name IS NULL 
                      OR @permission_name = '' ) ) 
            BEGIN 
                RAISERROR('NULL value for parameter',16,1) 
            END 


          INSERT INTO [dbo].[EmployeeHasPermission] 
                      (employee_id, 
                       permission_name, 
                       priority) 
          VALUES      (@employee_id, 
                       @permission_name, 
                       @priority); 

      END try 

      BEGIN catch 

          SELECT @ERR_MSG = Error_message(), 
                 @ERR_STA = Error_state(); 

          THROW 50001, @ERR_MSG, @ERR_STA; 
      END catch 
  END 


GO
/****** Object:  StoredProcedure [dbo].[spAddRoomToReservation]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
	Takes the reservation and the type of room to add as parameters.
	The procedure will figure which room number to add based on
	available rooms.
*/
CREATE PROCEDURE [dbo].[spAddRoomToReservation](
										@reservation_number AS INT,
										@room_type AS VARCHAR(50))
AS
BEGIN
	DECLARE
	      @ERR_MSG AS NVARCHAR(1000),
		  @ERR_STA AS SMALLINT

	--SET NOCOUNT ON;

	BEGIN TRY
	BEGIN TRANSACTION

		/*Check for null parameters*/
		IF (( @reservation_number IS NULL 
				OR @reservation_number = '' )
			OR ( @room_type IS NULL 
				OR @room_type = '' )) 
			BEGIN 
				RAISERROR('NULL value for parameter',16,1) 
			END

		/*Do not allow if guest has already checked in*/
		IF ( SELECT checked_in FROM Reservation WHERE reservation_number=@reservation_number ) = 1
		BEGIN
			RAISERROR('Guest has already checked in',16,1) 
		END

		/*Create Temp Table of Available Rooms*/
		CREATE TABLE #AvailableRoom(
			room_number nchar(8),
			room_type varchar(50)
		)

		/*Get the start and end dates from the reservation table*/
		DECLARE @start_date AS DATETIME
		DECLARE @end_date AS DATETIME

		SELECT TOP 1 @start_date=start_date
		FROM Reservation
		WHERE reservation_number = @reservation_number

		SELECT TOP 1 @end_date=end_date
		FROM Reservation
		WHERE reservation_number = @reservation_number

		/*Put the available rooms from date range into temp table*/
		INSERT INTO #AvailableRoom
		EXEC	[dbo].[spShowAvailableRooms]
				@start_date,
				@end_date

		DECLARE @room_number NCHAR(8)
		DECLARE @available_rooms SMALLINT
		DECLARE @room_price DECIMAL(19,4)
		DECLARE @number_of_days SMALLINT


		SELECT @available_rooms = COUNT(*) FROM #AvailableRoom WHERE room_type = @room_type

		/*If not enough available rooms, raise error*/

		IF ( ( 1 > @available_rooms ) ) 
			BEGIN 
				RAISERROR('Not enough available rooms',16,1) 
			END 

		SELECT @number_of_days = DATEDIFF(day,@start_date,@end_date)

		SELECT TOP 1 @room_number=room_number FROM #AvailableRoom WHERE room_type = @room_type ORDER BY room_type;

		/*Get price from room type and multiple by number of days for the stay*/
		SELECT TOP 1 @room_price=cost_per_day FROM RoomType WHERE room_type = @room_type
		SET @room_price = @room_price * @number_of_days

		INSERT INTO [dbo].[RoomForReservation]
			([reservation_number]
			,[room_number],
			[cost_for_stay])
		VALUES
			(@reservation_number
			,@room_number,
			@room_price);


	COMMIT TRANSACTION

	END TRY

    BEGIN CATCH 

	      SELECT @ERR_MSG = ERROR_MESSAGE(),
		  @ERR_STA = ERROR_STATE();
          THROW 50001, @ERR_MSG, @ERR_STA; 
		  
		  IF(@@TRANCOUNT > 0)
		  BEGIN
			PRINT 'Rolling Back'
			PRINT @@TRANCOUNT
			ROLLBACK TRANSACTION
		  END
	END CATCH 
END

GO
/****** Object:  StoredProcedure [dbo].[spCancelReservation]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spCancelReservation](
										@reservation_number AS INT)
AS
BEGIN
	DECLARE
	      @ERR_MSG AS NVARCHAR(1000),
		  @ERR_STA AS SMALLINT

	--SET NOCOUNT ON;

	BEGIN TRY
	BEGIN TRANSACTION

	/*Check for null parameter*/
	IF ( ( @reservation_number IS NULL 
                  OR @reservation_number = '' ) ) 
        BEGIN 
            RAISERROR('NULL value for parameter',16,1) 
        END 


	/*Delete all rooms for link table*/
	DELETE FROM RoomForReservation
	WHERE RoomForReservation.reservation_number = @reservation_number;
	/*Then delete the reservation itself*/
	DELETE FROM Reservation
	WHERE Reservation.reservation_number = @reservation_number;

	COMMIT TRANSACTION

	END TRY

    BEGIN CATCH 

	      SELECT @ERR_MSG = ERROR_MESSAGE(),
		  @ERR_STA = ERROR_STATE();
          THROW 50001, @ERR_MSG, @ERR_STA; 
		  
		  IF(@@TRANCOUNT > 0)
		  BEGIN
			PRINT 'Rolling Back'
			PRINT @@TRANCOUNT
			ROLLBACK TRANSACTION
		  END
	END CATCH 
END

GO
/****** Object:  StoredProcedure [dbo].[spChangePermissionPriorityForEmployee]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spChangePermissionPriorityForEmployee](@employee_id  AS INT, 
                                                   @permission_name   AS VARCHAR(50), 
                                                   @new_priority AS TINYINT) 
AS 
  BEGIN 
      DECLARE @ERR_MSG AS NVARCHAR(1000), 
              @ERR_STA AS SMALLINT 

      /*Check to see if parameters are acceptable*/ 
      BEGIN try 
          IF ( ( @employee_id IS NULL 
                  OR @employee_id = '' ) 
                OR ( @permission_name IS NULL 
                      OR @permission_name = '' ) ) 
            BEGIN 
                RAISERROR('NULL value for parameter',16,1) 
            END 

			DECLARE @old_permission_name AS VARCHAR(50)
		
			SELECT TOP 1 @old_permission_name=permission_name
			FROM EmployeeHasPermission
			WHERE priority = @new_priority
					AND employee_id = @employee_id

			UPDATE EmployeeHasPermission 
			SET    priority = NULL 
			WHERE  permission_name = @old_permission_name 
				AND employee_id = @employee_id

			UPDATE EmployeeHasPermission 
			SET    priority = @new_priority 
			WHERE  permission_name = @permission_name 
				AND employee_id = @employee_id 

      END try 

      BEGIN catch 

          SELECT @ERR_MSG = Error_message(), 
                 @ERR_STA = Error_state(); 

          THROW 50001, @ERR_MSG, @ERR_STA; 
      END catch 
  END 


GO
/****** Object:  StoredProcedure [dbo].[spCreateHousekeepingTicketFromReservation]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
	Generate Invoice for reservation
	Probably do this at checkin
*/
CREATE PROCEDURE [dbo].[spCreateHousekeepingTicketFromReservation](@reservation_number AS INT)
AS
BEGIN
	DECLARE
	      @ERR_MSG AS NVARCHAR(1000),
		  @ERR_STA AS SMALLINT

	--SET NOCOUNT ON;

	BEGIN TRY
	BEGIN TRANSACTION

	/*Check for null parameters*/
	IF ( ( @reservation_number IS NULL 
                  OR @reservation_number = '' ) ) 
        BEGIN 
            RAISERROR('NULL value for parameter',16,1) 
        END 
	
	--Create Ticket

	DECLARE @ticket_number INT

	INSERT INTO [dbo].[Ticket]
           ([ticket_type]
           ,[opened_by]
           ,[assigned_to]
           ,[closed_by]
           ,[title]
           ,[description]
           ,[date_closed]
           ,[priority])
     VALUES
		(
		'Housekeeping',
		NULL,
		NULL,
		NULL,
		'Clean room after checkout',
		'This is an autogenerated ticket to clean room after guest departure.',
		NULL,
		'Low'
		)

	--Get ticket_number of Ticket that was created
	SELECT TOP 1 @ticket_number=ticket_number
	FROM Ticket
	WHERE ticket_number = SCOPE_IDENTITY();
	
	--Add Rooms To Ticket
	INSERT INTO RoomForTicket(room_number,ticket_number)
	SELECT room_number, @ticket_number AS ticket_number
	FROM RoomForReservation
	WHERE RoomForReservation.reservation_number = @reservation_number

	COMMIT TRANSACTION

	END TRY

    BEGIN CATCH 

	      SELECT @ERR_MSG = ERROR_MESSAGE(),
		  @ERR_STA = ERROR_STATE();
          THROW 50001, @ERR_MSG, @ERR_STA; 
		  
		  IF(@@TRANCOUNT > 0)
		  BEGIN
			PRINT 'Rolling Back'
			PRINT @@TRANCOUNT
			ROLLBACK TRANSACTION
		  END
	END CATCH 
	PRINT @@TRANCOUNT
END

GO
/****** Object:  StoredProcedure [dbo].[spCreateInvoice]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
	Generate Invoice for reservation
	Probably do this at checkin
*/
CREATE PROCEDURE [dbo].[spCreateInvoice](@reservation_number AS INT)
AS
BEGIN
	DECLARE
	      @ERR_MSG AS NVARCHAR(1000),
		  @ERR_STA AS SMALLINT

	--SET NOCOUNT ON;

	BEGIN TRY
	BEGIN TRANSACTION

	/*Check for null parameters*/
	IF ( ( @reservation_number IS NULL 
                  OR @reservation_number = '' ) ) 
        BEGIN 
            RAISERROR('NULL value for parameter',16,1) 
        END 
	
	--Create Invoice
	INSERT INTO [dbo].[Invoice]
           ([reservation_number])
     VALUES
           (@reservation_number)

	--Create Charges for Invoice
	INSERT INTO Charge(invoice_number,amount,charge_date)
	SELECT 
		Invoice.invoice_number AS invoice_number, 
		cost_for_stay AS amount,
		start_date AS charge_date
	FROM 
		RoomForReservation
	INNER JOIN Invoice 
	ON RoomForReservation.reservation_number=Invoice.reservation_number
	INNER JOIN Reservation
	ON RoomForReservation.reservation_number = Reservation.reservation_number
	WHERE 
		Invoice.reservation_number=@reservation_number

	COMMIT TRANSACTION

	END TRY

    BEGIN CATCH 

	      SELECT @ERR_MSG = ERROR_MESSAGE(),
		  @ERR_STA = ERROR_STATE();
          THROW 50001, @ERR_MSG, @ERR_STA; 
		  
		  IF(@@TRANCOUNT > 0)
		  BEGIN
			PRINT 'Rolling Back'
			PRINT @@TRANCOUNT
			ROLLBACK TRANSACTION
		  END
	END CATCH 
	PRINT @@TRANCOUNT
END

GO
/****** Object:  StoredProcedure [dbo].[spCreateReservation]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spCreateReservation](
										@List AS dbo.RoomToReserve READONLY,
										@guest_id AS INT,
										@start_date AS DATETIME, 
                                        @end_date   AS DATETIME)
AS
BEGIN
	DECLARE
	      @ERR_MSG AS NVARCHAR(1000),
		  @ERR_STA AS SMALLINT

	--SET NOCOUNT ON;

	BEGIN TRY
	BEGIN TRANSACTION

	/*Check for null parameters*/
	IF ( ( @guest_id IS NULL 
                  OR @guest_id = '' ) 
		OR ( @start_date IS NULL 
                  OR @start_date = '' ) 
                OR ( @end_date IS NULL 
                      OR @end_date = '' ) ) 
        BEGIN 
            RAISERROR('NULL value for parameter',16,1) 
        END 

    IF ( @end_date <= @start_date ) 
		BEGIN 
			RAISERROR('End date is before Start date',16,1) 
        END 

          /*Truncate Datetime down to hour*/ 
          SET @start_date = Dateadd(hour, Datediff(hour, 0, @start_date), 0) 
          SET @end_date = Dateadd(hour, Datediff(hour, 0, @end_date), 0)

	
	DECLARE @reservation_number int

		INSERT INTO [dbo].[Reservation]
			([guest_id]
            ,[start_date]
            ,[end_date])
	 --OUTPUT inserted.reservation_number
		VALUES
			(@guest_id,
			@start_date,
			@end_date);

	SELECT TOP 1 @reservation_number=reservation_number
	FROM Reservation
	WHERE reservation_number = SCOPE_IDENTITY();
	PRINT @reservation_number 
	
	CREATE TABLE #RoomTypeToReserve(
		room_type VARCHAR(50)
	)

	;WITH
	#RoomToAdd AS (
		SELECT room_type, number_of_rooms, j=number_of_rooms-1
		FROM @List
	  UNION all
		SELECT room_type, number_of_rooms, j-1
		FROM #RoomToAdd
		WHERE j > 0
	)
	INSERT INTO #RoomTypeToReserve
	SELECT
	   room_type
	FROM #RoomToAdd
	ORDER BY room_type


	CREATE TABLE #AvailableRoom(
		room_number nchar(8),
		room_type varchar(50),
		cost_per_day DECIMAL(19,4)
	)

	  INSERT INTO #AvailableRoom
	  EXEC	[dbo].[spShowAvailableRooms]
			@start_date,
			@end_date


	DECLARE 
		@counter SMALLINT = 0,
		@max SMALLINT = 5
  
	DECLARE @room VARCHAR(50)
	DECLARE @room_number NCHAR(8)
	DECLARE @room_price DECIMAL(19,4)
	DECLARE @number_of_days SMALLINT
	DECLARE @available_rooms SMALLINT

	SELECT @available_rooms = COUNT(*) FROM #AvailableRoom
	SELECT @max = COUNT(*) FROM #RoomTypeToReserve

	SELECT * FROM #AvailableRoom
	SELECT * FROM #RoomTypeToReserve

	SELECT @number_of_days = DATEDIFF(day,@start_date,@end_date)

	/*If not enough available rooms, raise error*/

	IF ( ( @max > @available_rooms ) ) 
		BEGIN 
			RAISERROR('Not enough available rooms',16,1) 
        END 
	

	/*For each room in RoomTypeToReserver...*/
	WHILE @counter < @max
	BEGIN

		PRINT @counter

		SELECT * FROM #RoomTypeToReserve
		SELECT #AvailableRoom.room_number,#AvailableRoom.room_type FROM #AvailableRoom

		SELECT TOP 1 @room = room_type FROM #RoomTypeToReserve;

		/*Get price from room type and multiple by number of days for the stay*/
		SELECT TOP 1 @room_price=cost_per_day FROM RoomType WHERE room_type = @room

		SET @room_price = @room_price * @number_of_days

		SELECT TOP 1 @room_number=room_number FROM #AvailableRoom WHERE room_type = @room ORDER BY room_type;



		INSERT INTO [dbo].[RoomForReservation]
			   ([reservation_number]
			   ,[room_number],
			   [cost_for_stay])
		VALUES
			   (@reservation_number
			   ,@room_number,
			   @room_price);


		WITH q1 AS 
		(
		SELECT TOP 1 * 
		FROM #RoomTypeToReserve 
		WHERE room_type = @room 
		ORDER BY room_type
		)
		DELETE  FROM  q1;

		WITH q2 AS 
		(
		SELECT TOP 1 * 
		FROM #AvailableRoom 
		WHERE room_type = @room 
		ORDER BY room_type
		)
		DELETE FROM  q2;

		SET @counter = @counter + 1
	END
	/*End Loop*/

	COMMIT TRANSACTION

	END TRY

    BEGIN CATCH 

	      SELECT @ERR_MSG = ERROR_MESSAGE(),
		  @ERR_STA = ERROR_STATE();
          THROW 50001, @ERR_MSG, @ERR_STA; 
		  
		  IF(@@TRANCOUNT > 0)
		  BEGIN
			PRINT 'Rolling Back'
			PRINT @@TRANCOUNT
			ROLLBACK TRANSACTION
		  END
	END CATCH 

	DROP TABLE #AvailableRoom
	DROP TABLE #RoomTypeToReserve
	--DELETE FROM Reservation WHERE reservation_number = @reservation_number
	PRINT @@TRANCOUNT
END
GO
/****** Object:  StoredProcedure [dbo].[spRemovePermissionForEmployee]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spRemovePermissionForEmployee](@employee_id AS INT, 
                                           @permission_name  AS VARCHAR(50)) 
AS 
  BEGIN 
      DECLARE @ERR_MSG AS NVARCHAR(1000), 
              @ERR_STA AS SMALLINT 

      BEGIN try 
          IF ( ( @employee_id IS NULL 
                  OR @employee_id = '' ) 
                OR ( @permission_name IS NULL 
                      OR @permission_name = '' ) ) 
            BEGIN 
                RAISERROR('NULL value for parameter',16,1) 
            END 

          DELETE FROM [dbo].[EmployeeHasPermission] 
          WHERE  employee_id = @employee_id 
                 AND permission_name = @permission_name 

      END try 

      BEGIN catch 

          SELECT @ERR_MSG = Error_message(), 
                 @ERR_STA = Error_state(); 

          THROW 50001, @ERR_MSG, @ERR_STA; 
      END catch 
  END 


GO
/****** Object:  StoredProcedure [dbo].[spRemoveRoomFromReservation]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/*
	Takes the reservation and the type of room to remove as parameters.
	The procedure will figure out the room number to remove.
*/

CREATE PROCEDURE [dbo].[spRemoveRoomFromReservation](
										@reservation_number AS INT,
										@room_type AS VARCHAR(50))
AS
BEGIN
	DECLARE
	      @ERR_MSG AS NVARCHAR(1000),
		  @ERR_STA AS SMALLINT

	--SET NOCOUNT ON;

	BEGIN TRY
	BEGIN TRANSACTION

		/*Check for null parameter*/
		IF (( @reservation_number IS NULL 
				OR @reservation_number = '' ) 
			OR ( @room_type IS NULL 
				OR @room_type = '' )) 
			BEGIN 
				RAISERROR('NULL value for parameter',16,1) 
			END 

		/*Do not allow if guest has already checked in*/
		IF ( SELECT checked_in FROM Reservation WHERE reservation_number=@reservation_number ) = 1
		BEGIN
			RAISERROR('Guest has already checked in',16,1) 
		END
		
		DECLARE @room_number NCHAR(8)

		SELECT TOP 1 @room_number=RoomForReservation.room_number
		FROM RoomForReservation
		INNER JOIN Room
		ON RoomForReservation.room_number = Room.room_number
		WHERE room_type = @room_type
		AND reservation_number = @reservation_number

		DELETE TOP (1)
		FROM   RoomForReservation
		WHERE room_number=@room_number
		AND reservation_number=@reservation_number

	COMMIT TRANSACTION

	END TRY

    BEGIN CATCH 

	      SELECT @ERR_MSG = ERROR_MESSAGE(),
		  @ERR_STA = ERROR_STATE();
          THROW 50001, @ERR_MSG, @ERR_STA; 
		  
		  IF(@@TRANCOUNT > 0)
		  BEGIN
			PRINT 'Rolling Back'
			PRINT @@TRANCOUNT
			ROLLBACK TRANSACTION
		  END
	END CATCH 
END

GO
/****** Object:  StoredProcedure [dbo].[spShowAllReservations]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROC [dbo].[spShowAllReservations](@start_date AS DATETIME, 
                                         @end_date   AS DATETIME) 
AS 
  BEGIN 

	  DECLARE
	      @ERR_MSG AS NVARCHAR(1000),
		  @ERR_STA AS SMALLINT
	
      /*Check to see if parameters are acceptable*/ 
      BEGIN try 
          IF ( ( @start_date IS NULL 
                  OR @start_date = '' ) 
                AND ( @end_date IS NULL 
                      OR @end_date = '' ) ) 
            BEGIN 
                RAISERROR('both parameters are NULL',16,1) 
            END 

          IF ( @end_date <= @start_date ) 
            BEGIN 
                RAISERROR('End date is before Start date',16,1) 
            END 

          /*Truncate Datetime down to hour*/ 
          SET @start_date = Dateadd(hour, Datediff(hour, 0, @start_date), 0) 
          SET @end_date = Dateadd(hour, Datediff(hour, 0, @end_date), 0) 

		  /*
			Select all rooms that... 
				DO NOT have a reservation with a start date between the date range, 
				DO NOT have a reservation with an end date between the date range,
				DO NOT have a start date AND end date before and after the date range
		  */

          SELECT	
			dbo.Guest.first_name, dbo.Guest.last_name, dbo.Guest.email, dbo.Guest.phone_number, dbo.Reservation.reservation_number, dbo.Reservation.start_date, dbo.Reservation.end_date, 
			dbo.Reservation.checked_in, dbo.Reservation.checked_out, dbo.RoomForReservation.room_number, dbo.RoomForReservation.cost_for_stay
		  FROM	
			dbo.Guest
		  INNER JOIN
			dbo.Reservation ON dbo.Guest.guest_id = dbo.Reservation.guest_id
		  INNER JOIN
            dbo.RoomForReservation ON dbo.Reservation.reservation_number = dbo.RoomForReservation.reservation_number
		  WHERE 
			dbo.Reservation.start_date BETWEEN ISNULL(@start_date,'1999-01-01') AND ISNULL(@end_date,'2999-01-01')
      END try 

      BEGIN catch 

	      SELECT @ERR_MSG = ERROR_MESSAGE(),
		  @ERR_STA = ERROR_STATE();
          THROW 50001, @ERR_MSG, @ERR_STA; 

      END catch 
  END 




GO
/****** Object:  StoredProcedure [dbo].[spShowAvailableRooms]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROC [dbo].[spShowAvailableRooms](@start_date AS DATETIME, 
                                         @end_date   AS DATETIME) 
AS 
  BEGIN 

	  DECLARE
	      @ERR_MSG AS NVARCHAR(1000),
		  @ERR_STA AS SMALLINT
	
      /*Check to see if parameters are acceptable*/ 
      BEGIN try 
          IF ( ( @start_date IS NULL 
                  OR @start_date = '' ) 
                OR ( @end_date IS NULL 
                      OR @end_date = '' ) ) 
            BEGIN 
                RAISERROR('NULL value for parameter',16,1) 
            END 

          IF ( @end_date <= @start_date ) 
            BEGIN 
                RAISERROR('End date is before Start date',16,1) 
            END 

          /*Truncate Datetime down to hour*/ 
          SET @start_date = Dateadd(hour, Datediff(hour, 0, @start_date), 0) 
          SET @end_date = Dateadd(hour, Datediff(hour, 0, @end_date), 0) 

		  /*
			Select all rooms that... 
				DO NOT have a reservation with a start date between the date range, 
				DO NOT have a reservation with an end date between the date range,
				DO NOT have a start date AND end date before and after the date range
		  */

          SELECT room_number,Room.room_type,cost_per_day FROM Room
		  INNER JOIN RoomType
				ON Room.room_type = RoomType.room_type
		  EXCEPT
		  SELECT Room.room_number,Room.room_type,cost_per_day
          FROM   reservation 
                INNER JOIN RoomForReservation
                         ON Reservation.reservation_number = RoomForReservation.reservation_number 
				RIGHT JOIN Room
						 ON room.room_number = RoomForReservation.room_number
				INNER JOIN RoomType
						 ON Room.room_type = RoomType.room_type

          WHERE ( ( reservation.start_date BETWEEN 
                             @start_date AND @end_date
                           ) 
                            OR ( reservation.end_date BETWEEN 
                                @start_date AND @end_date )
							OR (Reservation.start_date <= @start_date AND 
								Reservation.end_date >= @end_date)
							) 	

      END try 

      BEGIN catch 

	      SELECT @ERR_MSG = ERROR_MESSAGE(),
		  @ERR_STA = ERROR_STATE();
          THROW 50001, @ERR_MSG, @ERR_STA; 

      END catch 
  END 





GO
/****** Object:  StoredProcedure [dbo].[spShowEmployeePermissions]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spShowEmployeePermissions](@employee_id AS INT) 
AS 
  BEGIN 
      DECLARE @ERR_MSG AS NVARCHAR(1000), 
              @ERR_STA AS SMALLINT 

      /*Check to see if parameters are acceptable*/ 
      BEGIN try 
          IF ( ( @employee_id IS NULL 
                  OR @employee_id = '' ) ) 
            BEGIN 
                RAISERROR('NULL value for parameter',16,1) 
            END 

          SELECT EmployeeHasPermission.employee_id, 
				 EmployeeHasPermission.permission_name,
				 priority,
				 description
		  FROM EmployeeHasPermission
		  INNER JOIN Permission
		  ON EmployeeHasPermission.permission_name = Permission.permission_name
		  WHERE employee_id=@employee_id
		  /*Order by priority, move NULLs to end*/
		  ORDER BY CASE WHEN priority IS NULL THEN 1 ELSE 0 END, priority;
      END try 

      BEGIN catch 
          SELECT @ERR_MSG = Error_message(), 
                 @ERR_STA = Error_state(); 

          THROW 50001, @ERR_MSG, @ERR_STA; 
      END catch 
  END 


GO
/****** Object:  StoredProcedure [dbo].[spShowRoomsWithReservation]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROC [dbo].[spShowRoomsWithReservation](@reservation_number AS INT) 
AS 
  BEGIN 

	  DECLARE
	      @ERR_MSG AS NVARCHAR(1000),
		  @ERR_STA AS SMALLINT
	
      /*Check to see if parameters are acceptable*/ 
      BEGIN try 
          IF ( ( @reservation_number IS NULL 
                  OR @reservation_number = '' ) ) 
            BEGIN 
                RAISERROR('NULL value for parameter',16,1) 
            END 

          SELECT RoomForReservation.room_number, 
                 Room.room_type,
				 RoomType.description,
				 RoomForReservation.cost_for_stay
          FROM   RoomForReservation 
                 INNER JOIN Room 
                         ON Room.room_number = RoomForReservation.room_number 
				 INNER JOIN RoomType
						 ON Room.room_type	= RoomType.room_type
          WHERE  RoomForReservation.reservation_number = @reservation_number 

      END try 

      BEGIN catch 

	      SELECT @ERR_MSG = ERROR_MESSAGE(),
		  @ERR_STA = ERROR_STATE();
          THROW 50001, @ERR_MSG, @ERR_STA; 

      END catch 
  END 




GO
/****** Object:  StoredProcedure [dbo].[spUpdateEmployee]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[spUpdateEmployee](@employee_id AS INT, 
                                        @username  AS VARCHAR(255) = NULL, 
                                        @first_name	AS VARCHAR(50) = NULL,
										@last_name AS VARCHAR(50) = NULL,
										@email AS VARCHAR(255) = NULL,
										@phone_number AS CHAR(50) = NULL,
										@password_hash AS VARCHAR(MAX) = NULL,
										@salt	AS VARCHAR(255) = NULL,
										@access_level AS TINYINT = NULL,
										@reset_key AS VARCHAR(36) = NULL
										) 

AS 
  BEGIN 
      DECLARE @ERR_MSG AS NVARCHAR(1000), 
              @ERR_STA AS SMALLINT 

      BEGIN try 
          IF ( ( @employee_id IS NULL 
                  OR @employee_id = '' ) ) 
            BEGIN 
                RAISERROR('NULL value for parameter',16,1) 
            END 

			UPDATE Employee
			SET username=ISNULL(@username,username),
				first_name=ISNULL(@first_name,first_name),
				last_name=ISNULL(@last_name,last_name),
				email=ISNULL(@email,email),
				phone_number=ISNULL(@phone_number,phone_number),
				password_hash=ISNULL(@password_hash,password_hash),
				salt=ISNULL(@salt,salt),
				access_level=ISNULL(@access_level,access_level),
				reset_key=ISNULL(@reset_key,reset_key)
			WHERE employee_id=@employee_id
          

      END try 

      BEGIN catch 

          SELECT @ERR_MSG = Error_message(), 
                 @ERR_STA = Error_state(); 

          THROW 50001, @ERR_MSG, @ERR_STA; 
      END catch 
  END 


GO
/****** Object:  Table [dbo].[Charge]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Charge](
	[charge_number] [int] IDENTITY(1,1) NOT NULL,
	[invoice_number] [int] NOT NULL,
	[amount] [decimal](19, 4) NOT NULL,
	[charge_date] [datetime] NULL,
 CONSTRAINT [PK_Charge] PRIMARY KEY CLUSTERED 
(
	[charge_number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Employee]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Employee](
	[employee_id] [int] IDENTITY(1,1) NOT NULL,
	[username] [varchar](255) NOT NULL,
	[first_name] [varchar](50) NULL,
	[last_name] [varchar](50) NULL,
	[email] [varchar](255) NOT NULL,
	[phone_number] [char](10) NULL,
	[password_hash] [varchar](max) NULL,
	[salt] [varchar](255) NULL,
	[access_level] [tinyint] NOT NULL,
	[reset_key] [varchar](36) NULL,
 CONSTRAINT [PK_Employee] PRIMARY KEY CLUSTERED 
(
	[employee_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[EmployeeHasPermission]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[EmployeeHasPermission](
	[employee_id] [int] NOT NULL,
	[permission_name] [varchar](50) NOT NULL,
	[priority] [tinyint] NULL,
 CONSTRAINT [PK_EmployeeHasPermission] PRIMARY KEY CLUSTERED 
(
	[employee_id] ASC,
	[permission_name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Guest]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Guest](
	[guest_id] [int] IDENTITY(1,1) NOT NULL,
	[first_name] [varchar](50) NOT NULL,
	[last_name] [varchar](50) NULL,
	[email] [varchar](255) NULL,
	[phone_number] [char](10) NULL,
 CONSTRAINT [PK_Guest] PRIMARY KEY CLUSTERED 
(
	[guest_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Invoice]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Invoice](
	[invoice_number] [int] IDENTITY(1,1) NOT NULL,
	[reservation_number] [int] NOT NULL,
	[paid] [bit] NOT NULL,
 CONSTRAINT [PK_Invoice] PRIMARY KEY CLUSTERED 
(
	[invoice_number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[JobTitle]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[JobTitle](
	[access_level] [tinyint] NOT NULL,
	[title] [varchar](50) NOT NULL,
	[description] [text] NULL,
 CONSTRAINT [PK_JobTitle] PRIMARY KEY CLUSTERED 
(
	[access_level] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Log]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Log](
	[log_id] [int] IDENTITY(1,1) NOT NULL,
	[log_type] [varchar](50) NOT NULL,
	[occured_at] [datetime] NOT NULL,
	[employee_id] [int] NULL,
	[message] [text] NULL,
	[workstation] [varchar](255) NULL,
	[event] [varchar](255) NULL,
 CONSTRAINT [PK_Log] PRIMARY KEY CLUSTERED 
(
	[log_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[LogType]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[LogType](
	[log_type] [varchar](50) NOT NULL,
	[description] [text] NULL,
 CONSTRAINT [PK_LogType] PRIMARY KEY CLUSTERED 
(
	[log_type] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Permission]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Permission](
	[permission_name] [varchar](50) NOT NULL,
	[description] [text] NULL,
	[access_level] [tinyint] NOT NULL,
 CONSTRAINT [PK_Permission] PRIMARY KEY CLUSTERED 
(
	[permission_name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Reservation]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Reservation](
	[reservation_number] [int] IDENTITY(1,1) NOT NULL,
	[guest_id] [int] NOT NULL,
	[start_date] [datetime] NOT NULL,
	[end_date] [datetime] NOT NULL,
	[checked_in] [bit] NOT NULL,
	[checked_out] [bit] NOT NULL,
 CONSTRAINT [PK_Reservation] PRIMARY KEY CLUSTERED 
(
	[reservation_number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Room]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Room](
	[room_number] [nchar](8) NOT NULL,
	[room_type] [varchar](50) NOT NULL,
	[max_occupancy] [smallint] NOT NULL,
	[last_cleaned] [datetime] NULL,
 CONSTRAINT [PK_Room] PRIMARY KEY CLUSTERED 
(
	[room_number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[RoomForReservation]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[RoomForReservation](
	[reservation_number] [int] NOT NULL,
	[room_number] [nchar](8) NOT NULL,
	[cost_for_stay] [decimal](19, 4) NOT NULL,
 CONSTRAINT [PK_RoomForReservation] PRIMARY KEY CLUSTERED 
(
	[reservation_number] ASC,
	[room_number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[RoomForTicket]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[RoomForTicket](
	[room_number] [nchar](8) NOT NULL,
	[ticket_number] [int] NOT NULL,
 CONSTRAINT [PK_RoomForTicket] PRIMARY KEY CLUSTERED 
(
	[room_number] ASC,
	[ticket_number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[RoomType]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[RoomType](
	[room_type] [varchar](50) NOT NULL,
	[cost_per_day] [decimal](19, 4) NOT NULL,
	[description] [text] NULL,
	[guest_room] [bit] NOT NULL,
	[rentable] [bit] NOT NULL,
 CONSTRAINT [PK_RoomType] PRIMARY KEY CLUSTERED 
(
	[room_type] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Ticket]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Ticket](
	[ticket_number] [int] IDENTITY(1,1) NOT NULL,
	[ticket_type] [varchar](50) NOT NULL,
	[opened_by] [int] NULL,
	[assigned_to] [int] NULL,
	[closed_by] [int] NULL,
	[title] [varchar](255) NOT NULL,
	[description] [text] NULL,
	[date_opened] [datetime] NOT NULL,
	[date_closed] [datetime] NULL,
	[priority] [varchar](10) NULL,
	[completed] [bit] NOT NULL,
 CONSTRAINT [PK_Ticket] PRIMARY KEY CLUSTERED 
(
	[ticket_number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[TicketType]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[TicketType](
	[ticket_type] [varchar](50) NOT NULL,
	[description] [text] NULL,
 CONSTRAINT [PK_TicketType] PRIMARY KEY CLUSTERED 
(
	[ticket_type] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Token]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Token](
	[token_id] [int] IDENTITY(1,1) NOT NULL,
	[token] [varchar](32) NOT NULL,
	[creation_date] [datetime] NULL,
	[employee_id] [int] NULL,
	[expiration_date] [datetime] NULL,
 CONSTRAINT [PK_Token] PRIMARY KEY CLUSTERED 
(
	[token_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  View [dbo].[BookedRoom]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[BookedRoom]
AS
SELECT        dbo.RoomForReservation.reservation_number, dbo.RoomForReservation.room_number, dbo.Room.room_type, dbo.RoomForReservation.cost_for_stay, dbo.Reservation.guest_id, dbo.Reservation.start_date, 
                         dbo.Reservation.end_date
FROM            dbo.Reservation INNER JOIN
                         dbo.RoomForReservation ON dbo.Reservation.reservation_number = dbo.RoomForReservation.reservation_number INNER JOIN
                         dbo.Room ON dbo.RoomForReservation.room_number = dbo.Room.room_number

GO
/****** Object:  View [dbo].[CheckInList]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[CheckInList]
AS
SELECT        dbo.Guest.first_name, dbo.Guest.last_name, dbo.Guest.email, dbo.Guest.phone_number, dbo.Reservation.start_date, dbo.Reservation.end_date, dbo.Reservation.reservation_number, dbo.Guest.guest_id, 
                         dbo.RoomForReservation.room_number, dbo.RoomForReservation.cost_for_stay
FROM            dbo.Reservation INNER JOIN
                         dbo.Guest ON dbo.Reservation.guest_id = dbo.Guest.guest_id INNER JOIN
                         dbo.RoomForReservation ON dbo.Reservation.reservation_number = dbo.RoomForReservation.reservation_number
WHERE        (dbo.Reservation.checked_in = 0)

GO
/****** Object:  View [dbo].[CheckOutList]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[CheckOutList]
AS
SELECT        dbo.Guest.guest_id, dbo.Guest.first_name, dbo.Guest.last_name, dbo.Guest.email, dbo.Guest.phone_number, dbo.Reservation.reservation_number, dbo.Reservation.start_date, dbo.Reservation.end_date, 
                         dbo.RoomForReservation.room_number, dbo.RoomForReservation.cost_for_stay
FROM            dbo.Reservation INNER JOIN
                         dbo.Guest ON dbo.Reservation.guest_id = dbo.Guest.guest_id INNER JOIN
                         dbo.RoomForReservation ON dbo.Reservation.reservation_number = dbo.RoomForReservation.reservation_number
WHERE        (dbo.Reservation.checked_in = 1) AND (dbo.Reservation.checked_out = 0)

GO
/****** Object:  View [dbo].[HousekeepingTicketList]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[HousekeepingTicketList]
AS
SELECT        dbo.Ticket.ticket_number, dbo.Ticket.ticket_type, dbo.Ticket.opened_by, dbo.Ticket.assigned_to, dbo.Ticket.closed_by, dbo.Ticket.title, dbo.Ticket.description, dbo.Ticket.date_opened, dbo.Ticket.date_closed, 
                         dbo.Ticket.priority, dbo.Ticket.completed, dbo.RoomForTicket.room_number, dbo.RoomForTicket.ticket_number AS Expr1
FROM            dbo.RoomForTicket INNER JOIN
                         dbo.Ticket ON dbo.RoomForTicket.ticket_number = dbo.Ticket.ticket_number
WHERE        (dbo.Ticket.completed = 0) AND (dbo.Ticket.ticket_type = 'Housekeeping')



GO
/****** Object:  View [dbo].[MaintenanceTicketList]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[MaintenanceTicketList]
AS
SELECT        dbo.Ticket.ticket_number, dbo.Ticket.ticket_type, dbo.Ticket.opened_by, dbo.Ticket.assigned_to, dbo.Ticket.closed_by, dbo.Ticket.title, dbo.Ticket.description, dbo.Ticket.date_opened, dbo.Ticket.date_closed, 
                         dbo.Ticket.priority, dbo.Ticket.completed, dbo.RoomForTicket.room_number, dbo.RoomForTicket.ticket_number AS Expr1
FROM            dbo.RoomForTicket INNER JOIN
                         dbo.Ticket ON dbo.RoomForTicket.ticket_number = dbo.Ticket.ticket_number
WHERE        (dbo.Ticket.completed = 0) AND (dbo.Ticket.ticket_type = 'Maintenance')



GO
/****** Object:  View [dbo].[OutstandingInvoice]    Script Date: 4/19/2017 7:44:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*SELECT invoice_number, Guest.guest_id, charge_number, amount, Charge.charge_date, first_name, last_name, email, phone_number 
FROM Invoice 
INNER JOIN Charge 
ON Invoice.invoice_number = Charge.invoice_number
INNER JOIN Guest
ON Invoice.guest_id = Guest.guest_id
*/
CREATE VIEW [dbo].[OutstandingInvoice]
AS
SELECT        dbo.Invoice.invoice_number, dbo.Guest.guest_id, dbo.Charge.charge_number, dbo.Charge.amount, dbo.Charge.charge_date, dbo.Guest.first_name, dbo.Guest.last_name, dbo.Guest.email, dbo.Guest.phone_number
FROM            dbo.Invoice INNER JOIN
                         dbo.Charge ON dbo.Invoice.invoice_number = dbo.Charge.invoice_number INNER JOIN
                         dbo.Guest ON dbo.Invoice.guest_id = dbo.Guest.guest_id




GO
SET IDENTITY_INSERT [dbo].[Charge] ON 

INSERT [dbo].[Charge] ([charge_number], [invoice_number], [amount], [charge_date]) VALUES (6, 1003, CAST(1840.0000 AS Decimal(19, 4)), CAST(0x0000A72E00000000 AS DateTime))
INSERT [dbo].[Charge] ([charge_number], [invoice_number], [amount], [charge_date]) VALUES (12, 1009, CAST(2480.0000 AS Decimal(19, 4)), CAST(0x0000A75A00735B40 AS DateTime))
INSERT [dbo].[Charge] ([charge_number], [invoice_number], [amount], [charge_date]) VALUES (13, 1009, CAST(1550.0000 AS Decimal(19, 4)), CAST(0x0000A75A00735B40 AS DateTime))
INSERT [dbo].[Charge] ([charge_number], [invoice_number], [amount], [charge_date]) VALUES (14, 1009, CAST(1550.0000 AS Decimal(19, 4)), CAST(0x0000A75A00735B40 AS DateTime))
INSERT [dbo].[Charge] ([charge_number], [invoice_number], [amount], [charge_date]) VALUES (15, 1009, CAST(2480.0000 AS Decimal(19, 4)), CAST(0x0000A75A00735B40 AS DateTime))
INSERT [dbo].[Charge] ([charge_number], [invoice_number], [amount], [charge_date]) VALUES (16, 1009, CAST(2480.0000 AS Decimal(19, 4)), CAST(0x0000A75A00735B40 AS DateTime))
SET IDENTITY_INSERT [dbo].[Charge] OFF
SET IDENTITY_INSERT [dbo].[Employee] ON 

INSERT [dbo].[Employee] ([employee_id], [username], [first_name], [last_name], [email], [phone_number], [password_hash], [salt], [access_level], [reset_key]) VALUES (3, N'bwarrington', N'Blake', N'Warrington', N'bwarring24@gmail.com', N'2169783051', N'0cfdf2de0f8773e81bd8bbb5ffb9a7f8ae90a40956a80acbae82cdb9aba7bba3', N'pickles&ham', 9, N'06002474-374d-4590-b8e3-7ae4779b3ae3')
INSERT [dbo].[Employee] ([employee_id], [username], [first_name], [last_name], [email], [phone_number], [password_hash], [salt], [access_level], [reset_key]) VALUES (5, N'tzee', N'Tim', N'Zee', N'tzee@kent.edu', NULL, N'16759b62e4892848d0e80d2214c11095d0f515a9743e1778b3991d3617017c02', N'0vi9q0rfgiud7typy0yv', 11, NULL)
INSERT [dbo].[Employee] ([employee_id], [username], [first_name], [last_name], [email], [phone_number], [password_hash], [salt], [access_level], [reset_key]) VALUES (6, N'tmcelrath', N'Tyrone', N'McElrath', N'tmcelrath@kent.edu', NULL, N'e43888d133f39b7c204f2fee7db45dc7376e6e5f82731b884b3157ef08b1a83b', N'm7wz4uyd6j3u24ua7z', 11, NULL)
INSERT [dbo].[Employee] ([employee_id], [username], [first_name], [last_name], [email], [phone_number], [password_hash], [salt], [access_level], [reset_key]) VALUES (1006, N'cblosser', N'Colin', N'Blosser', N'cblosser@kent.edu', NULL, N'cdcd81c470af99f01753d3fb7baca255dea1750fd8fd54efc323e9de3a63d37f', N'6hl465n6rzjei19h0baxbue7iu6t4bvs', 11, NULL)
INSERT [dbo].[Employee] ([employee_id], [username], [first_name], [last_name], [email], [phone_number], [password_hash], [salt], [access_level], [reset_key]) VALUES (1021, N'gbush', N'George', N'Bush', N'gbush@whitehouse.gov', N'1234567890', N'd581aee3732f00b6c29446077d7c0e4886c58ebf50b99e00dbc4fb2848c6512f', N'tI8QW1IG?ZKK^9FeX2zL7te0Bhuu8;*32SIz79;qKM:DslWX#Q?%MSg^?YjJ*ugZ', 7, NULL)
INSERT [dbo].[Employee] ([employee_id], [username], [first_name], [last_name], [email], [phone_number], [password_hash], [salt], [access_level], [reset_key]) VALUES (1022, N'fdesk', N'Front', N'Desk', N'fesk@hms.com', N'1234567890', N'6af883cd51fc4a2ee3f94fcb2226f083b61060d7946cc4308b43f868c670bab1', N'IAa;UEhTro27PK4Wylh;Bq7iIe4FuLn2GYvY4k31euc2ZUS9:BeM:gHzbSRJi378', 7, NULL)
INSERT [dbo].[Employee] ([employee_id], [username], [first_name], [last_name], [email], [phone_number], [password_hash], [salt], [access_level], [reset_key]) VALUES (1025, N'mgates', N'Melinda', N'Gates', N'bwarrin2@kent.edu', N'1234567890', N'77c2753e4a65ec5d836095945337ed2818bc8788b122707f5eb16d4df0c3c0e8', N'6WU!y52MN@s9d;6lhc7zzkz^o%r*0pic2s%y?1TAIboEoxlbtaYt$?Eo4VLwgvk6', 5, N'')
SET IDENTITY_INSERT [dbo].[Employee] OFF
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (3, N'ApproveRoomStatus', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (3, N'CanAddEmployee', 1)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (3, N'CanApproveSuggestedRoomRate', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (3, N'CancelHousekeepingRequest', 5)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (3, N'CancelMaintenanceRequest', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (3, N'CanChangeDigitalSignageVolume', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (3, N'CanEditEmployee', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (3, N'CanGrantPermission', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (3, N'CanRemoveEmployee', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (3, N'CanRestartServer', 6)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (3, N'CanRevokePermission', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (3, N'CanUpdateSoftware', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (3, N'ChangeKioskOnOff', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (3, N'ChangeTrainingOnOff', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (3, N'CheckInGuest', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (3, N'CheckOutGuest', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (3, N'CheckRoomStatus', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (3, N'HasFullSystemAccess', 0)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (3, N'RequestHousekeeping', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (3, N'RequestMaintenance', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (3, N'UseConcergieServices', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (3, N'WriteEmployeeCard', 3)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (3, N'WriteGuestCard', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (5, N'ApproveRoomStatus', 5)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (5, N'CanApproveSuggestedRoomRate', 2)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (5, N'CancelHousekeepingRequest', 8)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (5, N'ChangeTrainingOnOff', 3)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (5, N'CheckInGuest', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (5, N'CheckOutGuest', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (5, N'CheckRoomStatus', 0)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (5, N'HasFullSystemAccess', 7)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (5, N'WriteEmployeeCard', 1)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (6, N'HasFullSystemAccess', 1)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (1006, N'ChangeTrainingOnOff', 2)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (1006, N'HasFullSystemAccess', 0)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (1006, N'WriteEmployeeCard', 1)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (1021, N'CancelHousekeepingRequest', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (1021, N'CancelMaintenanceRequest', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (1021, N'CheckInGuest', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (1021, N'CheckOutGuest', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (1021, N'RequestHousekeeping', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (1021, N'RequestMaintenance', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (1022, N'CancelHousekeepingRequest', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (1022, N'CancelMaintenanceRequest', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (1022, N'CanChangeDigitalSignageVolume', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (1022, N'ChangeKioskOnOff', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (1022, N'CheckInGuest', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (1022, N'CheckOutGuest', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (1022, N'CheckRoomStatus', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (1022, N'RequestHousekeeping', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (1022, N'RequestMaintenance', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (1022, N'UseConcergieServices', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (1022, N'WriteGuestCard', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (1025, N'CancelMaintenanceRequest', NULL)
INSERT [dbo].[EmployeeHasPermission] ([employee_id], [permission_name], [priority]) VALUES (1025, N'ChangeMaintenanceStatus', NULL)
SET IDENTITY_INSERT [dbo].[Guest] ON 

INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (1, N'Jack', N'Stark', N'odio@vestibulumneque.net', N'2993389643')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (2, N'Shoshana', N'Delacruz', N'Nunc.sollicitudin@dapibus.org', N'4629297910')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (3, N'Blake', N'Warrington', N'vitae.erat@Nuncac.ca', N'1362502350')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (4, N'Ronan', N'Fry', N'tellus@enimmi.co.uk', N'4881538965')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (5, N'Tashya', N'Robbins', N'laoreet.posuere.enim@euligula.com', N'9808748443')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (6, N'Quinn', N'Boyd', N'Nam.tempor@acfeugiat.org', N'7527461258')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (7, N'Kyra', N'West', N'eget.varius@dolornonummyac.co.uk', N'7677142754')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (8, N'Mariam', N'Barry', N'luctus.ut.pellentesque@Phasellusdolorelit.co.uk', N'9854501426')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (9, N'Caldwell', N'Day', N'varius.Nam@vitaeposuereat.ca', N'3004235222')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (10, N'Rana', N'Golden', N'turpis@dolorsit.co.uk', N'3336764763')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (11, N'Kermit', N'Chandler', N'tempus.non@eu.co.uk', N'6556090630')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (12, N'Noelani', N'Foreman', N'diam.nunc.ullamcorper@Fuscefermentumfermentum.co.uk', N'8164888323')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (13, N'Hilel', N'Kaufman', N'nisi@eratinconsectetuer.ca', N'5461162422')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (14, N'Chester', N'Villarreal', N'Nunc@mauris.com', N'4754086553')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (15, N'Colton', N'Carlson', N'nostra.per@ac.co.uk', N'5276276828')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (16, N'Iliana', N'Holt', N'nisi.nibh.lacinia@maurisMorbinon.org', N'6415978456')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (17, N'Kareem', N'Hamilton', N'dui@aliquameu.org', N'9188487193')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (18, N'Keane', N'Baxter', N'magna@nunc.edu', N'7364075577')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (19, N'Alan', N'Collins', N'Sed.nunc@dictum.ca', N'6335601272')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (20, N'Madison', N'Orr', N'lectus@aliquamenimnec.org', N'3111444931')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (21, N'Hu', N'Mcintosh', N'varius.ultrices.mauris@parturientmontes.net', N'9803444726')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (22, N'Vernon', N'Grimes', N'nec.ante@at.com', N'1585693044')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (23, N'Imani', N'Whitfield', N'egestas.Fusce.aliquet@ipsumporta.edu', N'8848326889')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (24, N'Adam', N'Herman', N'euismod.in@nonarcu.ca', N'5808315592')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (25, N'Pandora', N'Leach', N'quis.urna@tristiquesenectus.edu', N'6757250669')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (26, N'Juliet', N'Reed', N'orci.sem.eget@scelerisque.com', N'1706585887')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (27, N'Suki', N'Hull', N'nunc.ac.mattis@urnaconvalliserat.net', N'7476728905')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (28, N'Lars', N'Warren', N'tellus@temporerat.co.uk', N'4969965705')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (29, N'Dalton', N'Francis', N'arcu@magnaseddui.net', N'6994183272')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (30, N'Evan', N'Navarro', N'ornare@justo.org', N'9557248830')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (31, N'Forrest', N'Castaneda', N'sit.amet.nulla@auctorMauris.ca', N'8412142472')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (32, N'Mariko', N'Potts', N'tempor.augue@acsemut.net', N'4625849541')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (33, N'Faith', N'York', N'ultrices.a@sitametante.co.uk', N'6005968392')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (34, N'Emily', N'Lester', N'nibh.enim.gravida@Classaptent.com', N'5901139194')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (35, N'Daria', N'Mckenzie', N'at@Vivamus.co.uk', N'1630351346')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (36, N'Chancellor', N'Rivers', N'tellus.non.magna@afelis.org', N'8681906742')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (37, N'Ian', N'Patton', N'justo.faucibus.lectus@nec.org', N'6685264245')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (38, N'Armando', N'Farmer', N'urna@miAliquamgravida.org', N'1780333350')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (39, N'Fleur', N'Case', N'cursus.in@justo.edu', N'4529111100')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (40, N'Trevor', N'Hampton', N'nec@in.org', N'6559248504')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (41, N'Remedios', N'Nunez', N'Duis.cursus.diam@magna.co.uk', N'7165056247')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (42, N'Neil', N'Landry', N'cursus.Nunc.mauris@congueelit.org', N'5382466845')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (43, N'Leslie', N'Hendricks', N'tristique.senectus@ultricies.org', N'5077579170')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (44, N'Casey', N'Wood', N'enim.Etiam@nibhlaciniaorci.co.uk', N'9558527917')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (45, N'Idola', N'Alvarez', N'at.libero.Morbi@volutpatNullafacilisis.org', N'1994710364')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (46, N'Baker', N'Mason', N'amet.consectetuer@laciniaSedcongue.ca', N'1989978708')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (47, N'Margaret', N'Newman', N'aliquet@Cumsociisnatoque.edu', N'5903900955')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (48, N'Grace', N'Caldwell', N'velit.Cras@nuncrisus.ca', N'3012928874')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (49, N'Magee', N'Alford', N'lobortis.augue.scelerisque@pharetranibh.co.uk', N'8354221949')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (50, N'Hayes', N'Downs', N'justo@justoeuarcu.edu', N'7617744690')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (51, N'Michelle', N'Rodriguez', N'Aenean@rhoncusProin.edu', N'5339402056')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (52, N'Yoshi', N'Rhodes', N'ultricies@nullamagna.net', N'4868298831')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (53, N'Nasim', N'Tyler', N'vulputate.lacus.Cras@tortor.net', N'8825462487')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (54, N'Abigail', N'Hughes', N'mi@vulputatenisi.edu', N'7496167050')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (55, N'Ralph', N'Burks', N'consectetuer@veliteget.com', N'5701096521')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (56, N'Chelsea', N'Cunningham', N'enim.Sed.nulla@Nunc.ca', N'1926977826')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (57, N'Karen', N'Vega', N'massa.Quisque.porttitor@luctus.com', N'3352800760')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (58, N'Ursula', N'Hopper', N'nunc.ullamcorper@tinciduntvehicula.co.uk', N'8602527591')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (59, N'Ashely', N'Donaldson', N'ultrices@ametluctus.com', N'6636979889')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (60, N'Jeanette', N'Burch', N'enim@velpede.com', N'5168065394')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (61, N'Derek', N'Navarro', N'Suspendisse.commodo@feugiatmetus.co.uk', N'3614823483')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (62, N'Lillian', N'Berger', N'faucibus@mauriseu.org', N'7684130432')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (63, N'Basia', N'Sears', N'blandit.mattis.Cras@posuere.co.uk', N'9002272896')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (64, N'Brielle', N'Hayden', N'mus.Aenean@iderat.net', N'7934279284')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (65, N'Orli', N'Collier', N'a.neque@justositamet.ca', N'2854295325')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (66, N'Ina', N'Acosta', N'dui.Cum.sociis@lectusNullamsuscipit.org', N'4472401377')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (67, N'Russell', N'Chavez', N'Proin.non.massa@interdumCurabitur.co.uk', N'1220708980')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (68, N'Shelly', N'Harvey', N'vitae.erat@Namtempor.edu', N'3752585728')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (69, N'Leila', N'Bailey', N'eget.odio@ornare.com', N'7162667748')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (70, N'Ezekiel', N'Jones', N'sem@eueratsemper.edu', N'6110617249')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (71, N'Haley', N'Cooper', N'auctor.vitae@perconubia.ca', N'5142928670')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (72, N'Kasper', N'Hinton', N'neque@nec.edu', N'4196916354')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (73, N'Amity', N'Robles', N'ipsum.primis.in@Cum.org', N'4066898292')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (74, N'Erica', N'Serrano', N'Mauris.vel@aliquamarcu.net', N'2988294242')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (75, N'Desirae', N'Chan', N'enim@turpisnecmauris.com', N'4245574278')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (76, N'Forrest', N'Walter', N'amet.consectetuer.adipiscing@laciniaSed.edu', N'7210305436')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (77, N'Brody', N'Stout', N'et.tristique.pellentesque@ullamcorperDuisat.org', N'9229185310')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (78, N'Troy', N'Bartlett', N'In.tincidunt@vulputaterisusa.com', N'8734316741')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (79, N'Nadine', N'Page', N'consequat.dolor@lobortisquispede.ca', N'3176100552')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (80, N'Celeste', N'Rush', N'laoreet.ipsum@odioapurus.com', N'5807340165')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (81, N'Oprah', N'Frederick', N'nibh.Donec.est@velarcu.com', N'4477807701')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (82, N'Ethan', N'Gomez', N'a@ipsumnuncid.com', N'5045217778')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (83, N'Anjolie', N'Mueller', N'Nam.consequat@nibh.net', N'5736138555')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (84, N'Samuel', N'Macias', N'felis.Nulla@Aliquamvulputate.edu', N'9803998699')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (85, N'Katell', N'Pate', N'ornare.placerat@quis.com', N'4784460345')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (86, N'Lacey', N'Allison', N'elit.fermentum.risus@arcuvel.com', N'2339747225')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (87, N'Noah', N'Wade', N'tempus.mauris@eunibhvulputate.net', N'5509695728')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (88, N'Sybil', N'Gilmore', N'eget.volutpat.ornare@rutrumloremac.ca', N'2506420695')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (89, N'Arden', N'Murray', N'orci@lectus.edu', N'8826664602')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (90, N'Tatyana', N'Leach', N'ullamcorper.magna@dolorsitamet.org', N'3240486326')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (91, N'Graiden', N'Howe', N'eu.ligula.Aenean@Sedeunibh.net', N'7028224703')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (92, N'Lester', N'Gilmore', N'natoque@consectetuer.ca', N'5875188976')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (93, N'Tatiana', N'Nixon', N'lorem.eget.mollis@eunullaat.ca', N'6976206365')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (94, N'Kylie', N'Preston', N'Curabitur@mi.co.uk', N'7368827467')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (95, N'September', N'Stevenson', N'at@blanditNamnulla.com', N'1217467526')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (96, N'Casey', N'Puckett', N'amet.risus@acturpisegestas.ca', N'2814433861')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (97, N'Serina', N'Wilkerson', N'lobortis.quis.pede@elementumloremut.org', N'9670199908')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (98, N'Ross', N'Cameron', N'Nunc@mattissemperdui.co.uk', N'5590415182')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (99, N'Madison', N'Mcpherson', N'nascetur@ornare.ca', N'6540648260')
GO
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (100, N'Victoria', N'Burt', N'erat.vitae@neceuismodin.co.uk', N'9323844100')
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (101, N'Tyrone', N'Mac', NULL, NULL)
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (102, N'Emil', N'thomas', NULL, NULL)
INSERT [dbo].[Guest] ([guest_id], [first_name], [last_name], [email], [phone_number]) VALUES (103, N'Mike', N'Pence', NULL, NULL)
SET IDENTITY_INSERT [dbo].[Guest] OFF
SET IDENTITY_INSERT [dbo].[Invoice] ON 

INSERT [dbo].[Invoice] ([invoice_number], [reservation_number], [paid]) VALUES (1003, 100, 0)
INSERT [dbo].[Invoice] ([invoice_number], [reservation_number], [paid]) VALUES (1009, 1, 0)
SET IDENTITY_INSERT [dbo].[Invoice] OFF
INSERT [dbo].[JobTitle] ([access_level], [title], [description]) VALUES (1, N'Guest', N'Guest')
INSERT [dbo].[JobTitle] ([access_level], [title], [description]) VALUES (2, N'Housekeeping', N'Housekeeping')
INSERT [dbo].[JobTitle] ([access_level], [title], [description]) VALUES (3, N'HousekeepingApprover', N'Housekeeping Approver')
INSERT [dbo].[JobTitle] ([access_level], [title], [description]) VALUES (4, N'HousekeepingSupervisor', N'Housekeeping Supervisor')
INSERT [dbo].[JobTitle] ([access_level], [title], [description]) VALUES (5, N'Maintenance', N'Maintenance')
INSERT [dbo].[JobTitle] ([access_level], [title], [description]) VALUES (6, N'MaintenanceSupervisor', N'Maintenance Supervisor')
INSERT [dbo].[JobTitle] ([access_level], [title], [description]) VALUES (7, N'FrontDeskAgent', N'Front Desk Agent')
INSERT [dbo].[JobTitle] ([access_level], [title], [description]) VALUES (8, N'NightAuditor', N'Night Auditor')
INSERT [dbo].[JobTitle] ([access_level], [title], [description]) VALUES (9, N'OperationsManager', N'Operations Manager')
INSERT [dbo].[JobTitle] ([access_level], [title], [description]) VALUES (10, N'GeneralManager', N'General Manager')
INSERT [dbo].[JobTitle] ([access_level], [title], [description]) VALUES (11, N'Administrator', N'Administrator')
INSERT [dbo].[JobTitle] ([access_level], [title], [description]) VALUES (12, N'Corporate', N'Corporate')
SET IDENTITY_INSERT [dbo].[Log] ON 

INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (1, N'ActionLog', CAST(0x0000A75900E9CBA7 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (2, N'ActionLog', CAST(0x0000A75900EA54EF AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (3, N'ActionLog', CAST(0x0000A75900EA61D4 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (4, N'ActionLog', CAST(0x0000A75901301B36 AS DateTime), NULL, NULL, NULL, NULL)
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (5, N'ActionLog', CAST(0x0000A759013020AA AS DateTime), NULL, NULL, NULL, NULL)
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (6, N'ActionLog', CAST(0x0000A759013336A8 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (7, N'ActionLog', CAST(0x0000A7590133467C AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (8, N'ActionLog', CAST(0x0000A7590133AA5F AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (9, N'ActionLog', CAST(0x0000A75901343334 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (10, N'ActionLog', CAST(0x0000A7590140E429 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (11, N'ActionLog', CAST(0x0000A7590140ED7C AS DateTime), 3, NULL, N'SURFACEBOOK', N'Requested Housekeeping')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (12, N'ActionLog', CAST(0x0000A7590140F3A9 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Cancelled Housekeeping Request')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (13, N'ActionLog', CAST(0x0000A7590140F637 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Cancelled Maintenance Request')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (14, N'ActionLog', CAST(0x0000A7590141F8B4 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (15, N'ActionLog', CAST(0x0000A7590141FD54 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Requested Maintenance')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (16, N'ActionLog', CAST(0x0000A7590141FEDE AS DateTime), 3, NULL, N'SURFACEBOOK', N'Cancelled Maintenance Request')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (17, N'ActionLog', CAST(0x0000A7590146CAA7 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (18, N'ActionLog', CAST(0x0000A7590146E302 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (19, N'ActionLog', CAST(0x0000A7590146E89D AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (20, N'ActionLog', CAST(0x0000A7590146F0E8 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (21, N'ActionLog', CAST(0x0000A75901473963 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (22, N'ActionLog', CAST(0x0000A75901476098 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Checked in a Guest')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (23, N'ActionLog', CAST(0x0000A75901479D70 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (24, N'ActionLog', CAST(0x0000A75901481A7B AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (25, N'ActionLog', CAST(0x0000A75901481EE1 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Checked in a Guest')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (26, N'ActionLog', CAST(0x0000A7590148687A AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (27, N'ActionLog', CAST(0x0000A7590149FD57 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (28, N'ActionLog', CAST(0x0000A759014A01C4 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Approved a Room''s Status')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (29, N'ActionLog', CAST(0x0000A759014A09EE AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Checked in a Guest')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (30, N'ActionLog', CAST(0x0000A759014A3FA9 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Cancelled Housekeeping Request')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (31, N'ActionLog', CAST(0x0000A759014A6932 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Checked out a Guest')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (32, N'ActionLog', CAST(0x0000A759014A7C2F AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Checked out a Guest')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (33, N'ActionLog', CAST(0x0000A759014A936F AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Using Full System Access')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (34, N'ActionLog', CAST(0x0000A759014A964F AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (35, N'ActionLog', CAST(0x0000A759014A9662 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Checked out a Guest')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (36, N'ActionLog', CAST(0x0000A759014A975C AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (37, N'ActionLog', CAST(0x0000A759014A9790 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Checked out a Guest')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (38, N'ActionLog', CAST(0x0000A759014A9866 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (39, N'ActionLog', CAST(0x0000A759014A987D AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Checked out a Guest')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (40, N'ActionLog', CAST(0x0000A759014A98DF AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (41, N'ActionLog', CAST(0x0000A759014A98DF AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Checked out a Guest')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (42, N'ActionLog', CAST(0x0000A759014A9945 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Checked out a Guest')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (43, N'ActionLog', CAST(0x0000A759014A9945 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (44, N'ActionLog', CAST(0x0000A759014A9997 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (45, N'ActionLog', CAST(0x0000A759014A99C5 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Checked out a Guest')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (46, N'ActionLog', CAST(0x0000A759014A99EF AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (47, N'ActionLog', CAST(0x0000A759014A99F8 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Checked out a Guest')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (48, N'ActionLog', CAST(0x0000A759014A9A86 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (49, N'ActionLog', CAST(0x0000A759014A9A86 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Checked out a Guest')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (50, N'ActionLog', CAST(0x0000A759014A9B2A AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (51, N'ActionLog', CAST(0x0000A759014A9B2E AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Checked out a Guest')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (52, N'ActionLog', CAST(0x0000A759014A9B6F AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (53, N'ActionLog', CAST(0x0000A759014A9B6F AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Checked out a Guest')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (54, N'ActionLog', CAST(0x0000A759014A9BA3 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (55, N'ActionLog', CAST(0x0000A759014A9BA3 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Checked out a Guest')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (56, N'ActionLog', CAST(0x0000A759014A9C0B AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (57, N'ActionLog', CAST(0x0000A759014A9C0C AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Checked out a Guest')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (58, N'ActionLog', CAST(0x0000A759014AF969 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Mode Changed to Training')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (59, N'ActionLog', CAST(0x0000A7590150EBEF AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (60, N'ActionLog', CAST(0x0000A7590150F0D5 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Using Full System Access')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (61, N'ActionLog', CAST(0x0000A75901511BFF AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (62, N'ActionLog', CAST(0x0000A75901511C0B AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Added a User')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (63, N'ActionLog', CAST(0x0000A759015145BB AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (64, N'ActionLog', CAST(0x0000A759015145EB AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (65, N'ActionLog', CAST(0x0000A759015554EC AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (66, N'ActionLog', CAST(0x0000A75901556408 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (67, N'ActionLog', CAST(0x0000A7590155D7BC AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (68, N'ActionLog', CAST(0x0000A75901562E13 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Using Full System Access')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (69, N'ActionLog', CAST(0x0000A75901570787 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (70, N'ActionLog', CAST(0x0000A759015F8127 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (71, N'ActionLog', CAST(0x0000A75901612372 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Hotel Room Price Approval')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (72, N'ActionLog', CAST(0x0000A759016126A3 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Mode Changed to Training')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (73, N'ActionLog', CAST(0x0000A75901638D64 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Using Full System Access')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (74, N'ActionLog', CAST(0x0000A75901638DAA AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Using Full System Access')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (75, N'ActionLog', CAST(0x0000A75901638DF2 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Using Full System Access')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (76, N'ActionLog', CAST(0x0000A75901638FA1 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (77, N'ActionLog', CAST(0x0000A75901638FAA AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Requested Housekeeping')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (78, N'ActionLog', CAST(0x0000A7590163944C AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (79, N'ActionLog', CAST(0x0000A75901639451 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Viewed a Maintenance Report')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (80, N'ActionLog', CAST(0x0000A759016398A3 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (81, N'ActionLog', CAST(0x0000A759016398A3 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Wrote an Employee Room Card')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (82, N'ActionLog', CAST(0x0000A75901639AC1 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (83, N'ActionLog', CAST(0x0000A75901639AC1 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Mode Changed to Kiosk Lock')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (84, N'ActionLog', CAST(0x0000A75901675119 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (85, N'ActionLog', CAST(0x0000A75901675168 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (86, N'ActionLog', CAST(0x0000A75901675171 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (87, N'ActionLog', CAST(0x0000A75901675176 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (88, N'ActionLog', CAST(0x0000A759016E874A AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (89, N'ActionLog', CAST(0x0000A759016E8C55 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Hotel Room Price Approval')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (90, N'ActionLog', CAST(0x0000A759016E8D3E AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Wrote an Employee Room Card')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (91, N'ActionLog', CAST(0x0000A759016E8E32 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Mode Changed to Training')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (92, N'ActionLog', CAST(0x0000A75901749077 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (93, N'ActionLog', CAST(0x0000A75901751472 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (94, N'ActionLog', CAST(0x0000A75901751DC7 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Using Full System Access')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (95, N'ActionLog', CAST(0x0000A75901752514 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Using Full System Access')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (96, N'ActionLog', CAST(0x0000A75901752548 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Using Full System Access')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (97, N'ActionLog', CAST(0x0000A7590175263A AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Using Full System Access')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (98, N'ActionLog', CAST(0x0000A759017526F4 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Using Full System Access')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (99, N'ActionLog', CAST(0x0000A75901752794 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Using Full System Access')
GO
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (100, N'ActionLog', CAST(0x0000A75901752823 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Using Full System Access')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (101, N'ActionLog', CAST(0x0000A75901752D25 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (102, N'ActionLog', CAST(0x0000A7590134F7DD AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (103, N'ActionLog', CAST(0x0000A7590135066A AS DateTime), 3, NULL, N'SURFACEBOOK', N'Using Full System Access')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (104, N'ActionLog', CAST(0x0000A75901350E66 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (105, N'ActionLog', CAST(0x0000A75901355F7D AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (106, N'ActionLog', CAST(0x0000A75901356545 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Using Full System Access')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (107, N'ActionLog', CAST(0x0000A75901356A29 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (108, N'ActionLog', CAST(0x0000A75901363470 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (109, N'ActionLog', CAST(0x0000A75901363B90 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (110, N'ActionLog', CAST(0x0000A75901363D45 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Using Full System Access')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (111, N'ActionLog', CAST(0x0000A75901369643 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (112, N'ActionLog', CAST(0x0000A75901369DFD AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (113, N'ActionLog', CAST(0x0000A75901369E04 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Using Full System Access')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (114, N'ActionLog', CAST(0x0000A7590138277B AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (115, N'ActionLog', CAST(0x0000A75901382D7B AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (116, N'ActionLog', CAST(0x0000A75901382D87 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Using Full System Access')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (117, N'ActionLog', CAST(0x0000A7590138C632 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (118, N'ActionLog', CAST(0x0000A7590138CE58 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Using Full System Access')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (119, N'ActionLog', CAST(0x0000A7590138D17F AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (120, N'ActionLog', CAST(0x0000A7590139FA05 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (121, N'ActionLog', CAST(0x0000A759013A14C6 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (122, N'ActionLog', CAST(0x0000A759013A1654 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Using Full System Access')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (123, N'ActionLog', CAST(0x0000A759013FF008 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (124, N'ActionLog', CAST(0x0000A759013FF89E AS DateTime), 3, NULL, N'SURFACEBOOK', N'Using Full System Access')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (125, N'ActionLog', CAST(0x0000A759013FFDB5 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (126, N'ActionLog', CAST(0x0000A7590140D418 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (127, N'ActionLog', CAST(0x0000A7590140DB9D AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (128, N'ActionLog', CAST(0x0000A7590140DBA9 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Using Full System Access')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (129, N'ActionLog', CAST(0x0000A75A000E0621 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (130, N'ActionLog', CAST(0x0000A75A000E11DD AS DateTime), 3, NULL, N'SURFACEBOOK', N'Cancelled Housekeeping Request')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (131, N'ActionLog', CAST(0x0000A75A000E28CE AS DateTime), 3, NULL, N'SURFACEBOOK', N'Cancelled Housekeeping Request')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (132, N'ActionLog', CAST(0x0000A75A000E2D2A AS DateTime), 3, NULL, N'SURFACEBOOK', N'Cancelled Maintenance Request')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (133, N'ActionLog', CAST(0x0000A75A000E3046 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Cancelled Housekeeping Request')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (134, N'ActionLog', CAST(0x0000A75A000E33A2 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (135, N'ActionLog', CAST(0x0000A75A000EA51B AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (136, N'ActionLog', CAST(0x0000A75A000EA871 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Cancelled Housekeeping Request')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (137, N'ActionLog', CAST(0x0000A7590158AECD AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (138, N'ActionLog', CAST(0x0000A7590158B8E3 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Cancelled Housekeeping Request')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (139, N'ActionLog', CAST(0x0000A75A000FBB75 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (140, N'ActionLog', CAST(0x0000A75A000FBE29 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Cancelled Housekeeping Request')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (141, N'ActionLog', CAST(0x0000A75A00100215 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Cancelled Housekeeping Request')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (142, N'ActionLog', CAST(0x0000A75A00101E23 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (143, N'ActionLog', CAST(0x0000A75A00102064 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Cancelled Housekeeping Request')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (144, N'ActionLog', CAST(0x0000A75A00103ECF AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (145, N'ActionLog', CAST(0x0000A75A00104141 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Cancelled Housekeeping Request')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (146, N'ActionLog', CAST(0x0000A75A00104AD1 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (147, N'ActionLog', CAST(0x0000A75A00105E9E AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (148, N'ActionLog', CAST(0x0000A75A001060DF AS DateTime), 3, NULL, N'SURFACEBOOK', N'Cancelled Housekeeping Request')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (149, N'ActionLog', CAST(0x0000A75A0010669B AS DateTime), 3, NULL, N'SURFACEBOOK', N'Cancelled Housekeeping Request')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (150, N'ErrorLog', CAST(0x0000A75A001066B2 AS DateTime), NULL, N'Failed to remove housekeeping ticket', NULL, NULL)
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (151, N'ActionLog', CAST(0x0000A759015A46AE AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (152, N'ActionLog', CAST(0x0000A759015A58A6 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Cancelled Housekeeping Request')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (153, N'ActionLog', CAST(0x0000A759015A6952 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Cancelled Housekeeping Request')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (154, N'ErrorLog', CAST(0x0000A759015A6961 AS DateTime), NULL, N'Failed to remove housekeeping ticket', NULL, NULL)
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (155, N'ActionLog', CAST(0x0000A759015AD4C9 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (156, N'ActionLog', CAST(0x0000A75A0011BB53 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (157, N'ActionLog', CAST(0x0000A75A0011C6AE AS DateTime), 3, NULL, N'SURFACEBOOK', N'Cancelled Housekeeping Request')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (158, N'ErrorLog', CAST(0x0000A75A0011CA49 AS DateTime), NULL, N'Failed to remove housekeeping ticket', NULL, NULL)
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (159, N'ActionLog', CAST(0x0000A75A0011D347 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Requested Maintenance')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (160, N'ActionLog', CAST(0x0000A75A0011EF40 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Checked a Room''s Status')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (161, N'ActionLog', CAST(0x0000A75A0011F159 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Used Concergie Services')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (162, N'ActionLog', CAST(0x0000A75A00123B8A AS DateTime), 3, NULL, N'SURFACEBOOK', N'Deleted a User')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (163, N'ActionLog', CAST(0x0000A75A00125C9D AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (164, N'ActionLog', CAST(0x0000A759015CF040 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (165, N'ActionLog', CAST(0x0000A759015CEFF5 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (166, N'ActionLog', CAST(0x0000A759015CF041 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Deleted a User')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (167, N'ActionLog', CAST(0x0000A759015CF037 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Deleted a User')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (168, N'ActionLog', CAST(0x0000A759015D2C86 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (169, N'ActionLog', CAST(0x0000A759015D3736 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Deleted a User')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (170, N'ActionLog', CAST(0x0000A759015D9EBB AS DateTime), 3, NULL, N'SURFACEBOOK', N'Cancelled Housekeeping Request')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (171, N'ErrorLog', CAST(0x0000A759015DD956 AS DateTime), NULL, N'Failed to remove housekeeping ticket', NULL, NULL)
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (172, N'ActionLog', CAST(0x0000A759015E5C68 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Deleted a User')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (173, N'ActionLog', CAST(0x0000A75A0015B9A8 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (174, N'ActionLog', CAST(0x0000A75A0015C5AD AS DateTime), 3, NULL, N'SURFACEBOOK', N'Deleted a User')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (175, N'ActionLog', CAST(0x0000A75A0015CBB6 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Deleted a User')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (176, N'ActionLog', CAST(0x0000A75A0015EC1D AS DateTime), 3, NULL, N'SURFACEBOOK', N'Requested Maintenance')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (177, N'ActionLog', CAST(0x0000A75A0015FE48 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Requested Housekeeping')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (178, N'ErrorLog', CAST(0x0000A75A0015FE64 AS DateTime), NULL, N'Unable to create new maintenance ticket', NULL, NULL)
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (179, N'ActionLog', CAST(0x0000A75A00160B9E AS DateTime), 3, NULL, N'SURFACEBOOK', N'Requested Housekeeping')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (180, N'ErrorLog', CAST(0x0000A75A00160BB3 AS DateTime), NULL, N'Unable to create new housekeeping ticket', NULL, NULL)
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (181, N'ActionLog', CAST(0x0000A75A00161F9B AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (182, N'ActionLog', CAST(0x0000A75A004705FA AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (183, N'ActionLog', CAST(0x0000A75A004713A5 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (184, N'ActionLog', CAST(0x0000A75A0047166C AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (185, N'ActionLog', CAST(0x0000A75A004828FD AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (186, N'ActionLog', CAST(0x0000A75A00483011 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (187, N'ActionLog', CAST(0x0000A75A00485676 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (188, N'ActionLog', CAST(0x0000A75A0048765D AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (189, N'ActionLog', CAST(0x0000A75A0048A42A AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (190, N'ActionLog', CAST(0x0000A75A004B7976 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (191, N'ActionLog', CAST(0x0000A75A004B8981 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (192, N'ActionLog', CAST(0x0000A75A004B8B06 AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (193, N'ActionLog', CAST(0x0000A75A004C255E AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (194, N'ActionLog', CAST(0x0000A75A004C2A49 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (195, N'ActionLog', CAST(0x0000A75A004C2B97 AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (196, N'ActionLog', CAST(0x0000A75A004C30F9 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (197, N'ActionLog', CAST(0x0000A75A004C311E AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (198, N'ActionLog', CAST(0x0000A75A004CC70F AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (199, N'ActionLog', CAST(0x0000A75A004CCABE AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
GO
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (200, N'ActionLog', CAST(0x0000A75A004CCBD4 AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (201, N'ActionLog', CAST(0x0000A75A004D094F AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (202, N'ActionLog', CAST(0x0000A75A004D0D97 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (203, N'ActionLog', CAST(0x0000A75A004D0EE7 AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (204, N'ActionLog', CAST(0x0000A75A004D1E4F AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (205, N'ActionLog', CAST(0x0000A75A004D1F74 AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (206, N'ActionLog', CAST(0x0000A75A004D1FAB AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (207, N'ActionLog', CAST(0x0000A75A004D1FD0 AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (208, N'ActionLog', CAST(0x0000A75A004D2040 AS DateTime), 3, NULL, N'System', N'Mode Changed to Normal')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (209, N'ActionLog', CAST(0x0000A75A004D2085 AS DateTime), 3, NULL, N'System', N'Mode Changed to Normal')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (210, N'ActionLog', CAST(0x0000A75A004D20CD AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (211, N'ActionLog', CAST(0x0000A75A004D20F5 AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (212, N'ActionLog', CAST(0x0000A75A004D2133 AS DateTime), 3, NULL, N'System', N'Mode Changed to Normal')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (213, N'ActionLog', CAST(0x0000A75A004D23A3 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (214, N'ActionLog', CAST(0x0000A75A004D23D7 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (215, N'ActionLog', CAST(0x0000A75A004D351A AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (216, N'ActionLog', CAST(0x0000A75A004D3968 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (217, N'ActionLog', CAST(0x0000A75A004D3A5D AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (218, N'ActionLog', CAST(0x0000A75A004D3BDF AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (219, N'ActionLog', CAST(0x0000A75A004D3D2A AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (220, N'ActionLog', CAST(0x0000A75A004D3D56 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (221, N'ActionLog', CAST(0x0000A75A004DC0B2 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (222, N'ActionLog', CAST(0x0000A75A004DC50E AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (223, N'ActionLog', CAST(0x0000A75A004DC691 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (224, N'ActionLog', CAST(0x0000A75A004DC7A3 AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (225, N'ActionLog', CAST(0x0000A75A004DC941 AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (226, N'ActionLog', CAST(0x0000A75A004DCAA9 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (227, N'ActionLog', CAST(0x0000A75A004DCAD0 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (228, N'ActionLog', CAST(0x0000A75A004DCADE AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (229, N'ActionLog', CAST(0x0000A75A004E3D34 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (230, N'ActionLog', CAST(0x0000A75A004E4177 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (231, N'ActionLog', CAST(0x0000A75A004E424D AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (232, N'ActionLog', CAST(0x0000A75A004E48C0 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (233, N'ActionLog', CAST(0x0000A75A004E48E0 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (234, N'ActionLog', CAST(0x0000A75A004EA2AF AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (235, N'ActionLog', CAST(0x0000A75A004EADAE AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (236, N'ActionLog', CAST(0x0000A75A004EAE8A AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (237, N'ActionLog', CAST(0x0000A75A005017BB AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (238, N'ActionLog', CAST(0x0000A75A00501AF4 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (239, N'ActionLog', CAST(0x0000A75A00501C58 AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (240, N'ActionLog', CAST(0x0000A75A005040FC AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (241, N'ActionLog', CAST(0x0000A75A005044F4 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (242, N'ActionLog', CAST(0x0000A75A0050464D AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (243, N'ActionLog', CAST(0x0000A75A005047CA AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (244, N'ActionLog', CAST(0x0000A75A00504904 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (245, N'ActionLog', CAST(0x0000A75A00504932 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (246, N'ActionLog', CAST(0x0000A75A0050AB0C AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (247, N'ActionLog', CAST(0x0000A75A0050AEE7 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (248, N'ActionLog', CAST(0x0000A75A0050AFFC AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (249, N'ActionLog', CAST(0x0000A75A0050BC75 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (250, N'ActionLog', CAST(0x0000A75A0050BCA0 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (251, N'ActionLog', CAST(0x0000A75A0050FE00 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (252, N'ActionLog', CAST(0x0000A75A00510197 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (253, N'ActionLog', CAST(0x0000A75A00510352 AS DateTime), 3, NULL, N'System', N'Mode Changed to Normal')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (254, N'ActionLog', CAST(0x0000A75A00510582 AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (255, N'ActionLog', CAST(0x0000A75A00510772 AS DateTime), 3, NULL, N'System', N'Mode Changed to Normal')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (256, N'ActionLog', CAST(0x0000A75A0051085F AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (257, N'ActionLog', CAST(0x0000A75A00510901 AS DateTime), 3, NULL, N'System', N'Mode Changed to Normal')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (258, N'ActionLog', CAST(0x0000A75A0051099D AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (259, N'ActionLog', CAST(0x0000A75A00510A27 AS DateTime), 3, NULL, N'System', N'Mode Changed to Normal')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (260, N'ActionLog', CAST(0x0000A75A00510AC1 AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (261, N'ActionLog', CAST(0x0000A75A00510BAE AS DateTime), 3, NULL, N'System', N'Mode Changed to Normal')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (262, N'ActionLog', CAST(0x0000A75A00510C65 AS DateTime), 3, NULL, N'System', N'Mode Changed to Normal')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (263, N'ActionLog', CAST(0x0000A75A00510C7D AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (264, N'ActionLog', CAST(0x0000A75A00510DA6 AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (265, N'ActionLog', CAST(0x0000A75A00511B49 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (266, N'ActionLog', CAST(0x0000A75A00511B65 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (267, N'ActionLog', CAST(0x0000A75A00515786 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (268, N'ActionLog', CAST(0x0000A75A00515D6C AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (269, N'ActionLog', CAST(0x0000A75A00515EA4 AS DateTime), 3, NULL, N'System', N'Mode Changed to Normal')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (270, N'ActionLog', CAST(0x0000A75A0051603D AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (271, N'ActionLog', CAST(0x0000A75A00516231 AS DateTime), 3, NULL, N'System', N'Mode Changed to Normal')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (272, N'ActionLog', CAST(0x0000A75A005162B4 AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (273, N'ActionLog', CAST(0x0000A75A0051664D AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (274, N'ActionLog', CAST(0x0000A75A00516669 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (275, N'ActionLog', CAST(0x0000A75A0051E670 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (276, N'ActionLog', CAST(0x0000A75A0051EAB0 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (277, N'ActionLog', CAST(0x0000A75A0051EB97 AS DateTime), 3, NULL, N'System', N'Mode Changed to Normal')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (278, N'ActionLog', CAST(0x0000A75A0051ECF1 AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (279, N'ActionLog', CAST(0x0000A75A00523148 AS DateTime), 3, NULL, N'System', N'Mode Changed to Normal')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (280, N'ActionLog', CAST(0x0000A75A0053F12B AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (281, N'ActionLog', CAST(0x0000A75A0053F581 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (282, N'ActionLog', CAST(0x0000A75A0053F799 AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (283, N'ActionLog', CAST(0x0000A75A0056B4D1 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (284, N'ActionLog', CAST(0x0000A75A0056BB88 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (285, N'ActionLog', CAST(0x0000A75A0056BD1A AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (286, N'ActionLog', CAST(0x0000A75A0056F4C8 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (287, N'ActionLog', CAST(0x0000A75A0056F939 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (288, N'ActionLog', CAST(0x0000A75A0056FA2F AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (289, N'ActionLog', CAST(0x0000A75A00573DFA AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (290, N'ActionLog', CAST(0x0000A75A0057433E AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (291, N'ActionLog', CAST(0x0000A75A00574436 AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (292, N'ActionLog', CAST(0x0000A75A0057ABC6 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (293, N'ActionLog', CAST(0x0000A75A0057C807 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (294, N'ActionLog', CAST(0x0000A75A0057C8F0 AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (295, N'ActionLog', CAST(0x0000A75A0058A617 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (296, N'ActionLog', CAST(0x0000A75A0058AA4D AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (297, N'ActionLog', CAST(0x0000A75A0058ABD9 AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (298, N'ActionLog', CAST(0x0000A75A005C2EE8 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (299, N'ActionLog', CAST(0x0000A75A005C331E AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
GO
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (300, N'ActionLog', CAST(0x0000A75A005C3413 AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (301, N'ActionLog', CAST(0x0000A75A005C8532 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (302, N'ActionLog', CAST(0x0000A75A005C890A AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (303, N'ActionLog', CAST(0x0000A75A005C8A44 AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (304, N'ActionLog', CAST(0x0000A75A005C9849 AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (305, N'ActionLog', CAST(0x0000A75A005CE19F AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (306, N'ActionLog', CAST(0x0000A75A005CE58F AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (307, N'ActionLog', CAST(0x0000A75A005CE669 AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (308, N'ActionLog', CAST(0x0000A75A005D3AC5 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (309, N'ActionLog', CAST(0x0000A75A005D3F17 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (310, N'ActionLog', CAST(0x0000A75A005D402A AS DateTime), 3, NULL, N'System', N'Mode Changed to Normal')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (311, N'ActionLog', CAST(0x0000A75A005D4185 AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (312, N'ActionLog', CAST(0x0000A75A005D4966 AS DateTime), 3, NULL, N'System', N'Mode Changed to Normal')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (313, N'ActionLog', CAST(0x0000A75A005D4B31 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (314, N'ActionLog', CAST(0x0000A75A005E0218 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (315, N'ActionLog', CAST(0x0000A75A005E0648 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (316, N'ActionLog', CAST(0x0000A75A005E077F AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (317, N'ActionLog', CAST(0x0000A75A005E0BEF AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (318, N'ActionLog', CAST(0x0000A75A005E0D03 AS DateTime), 3, NULL, N'System', N'Mode Changed to Normal')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (319, N'ActionLog', CAST(0x0000A75A005E54E5 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (320, N'ActionLog', CAST(0x0000A75A005E5917 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (321, N'ActionLog', CAST(0x0000A75A005E59FC AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (322, N'ActionLog', CAST(0x0000A75A005E5BD2 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (323, N'ActionLog', CAST(0x0000A75A005E5BE9 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (324, N'ActionLog', CAST(0x0000A75A006B0DF9 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (325, N'ActionLog', CAST(0x0000A75A006B2722 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (326, N'ActionLog', CAST(0x0000A75A006B4BFA AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (327, N'ActionLog', CAST(0x0000A75A006B7A9C AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (328, N'ActionLog', CAST(0x0000A75A002A7886 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (329, N'ActionLog', CAST(0x0000A75A002B28E6 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (330, N'ActionLog', CAST(0x0000A75A002BC63C AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (331, N'ActionLog', CAST(0x0000A75A002BD412 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (332, N'ActionLog', CAST(0x0000A75A002C2A40 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (333, N'ActionLog', CAST(0x0000A75A00C3258F AS DateTime), 3, NULL, N'BOW124BW', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (334, N'ActionLog', CAST(0x0000A75A00C3FDA1 AS DateTime), 3, NULL, N'BOW124BW', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (335, N'ActionLog', CAST(0x0000A75A00C41339 AS DateTime), 3, NULL, N'BOW124BW', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (336, N'ActionLog', CAST(0x0000A75A00C43DC2 AS DateTime), 3, NULL, N'BOW124BW', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (337, N'ActionLog', CAST(0x0000A75A00C608A8 AS DateTime), 3, NULL, N'BOW124BW', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (338, N'ActionLog', CAST(0x0000A75A00CBE404 AS DateTime), 3, NULL, N'BOW124BW', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (339, N'ActionLog', CAST(0x0000A75A00CBEF77 AS DateTime), 3, NULL, N'BOW124BW', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (340, N'ActionLog', CAST(0x0000A75A00CC9398 AS DateTime), 3, NULL, N'BOW124BW', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (341, N'ActionLog', CAST(0x0000A75A00CCC4CD AS DateTime), 3, NULL, N'BOW124BW', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (342, N'ActionLog', CAST(0x0000A75A00CD1145 AS DateTime), 3, NULL, N'BOW124BW', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (343, N'ActionLog', CAST(0x0000A75A00CEEE2B AS DateTime), 3, NULL, N'BOW124BW', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (344, N'ActionLog', CAST(0x0000A75A011684F0 AS DateTime), 3, NULL, N'BOW124BW', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (345, N'ActionLog', CAST(0x0000A75A01174068 AS DateTime), 3, NULL, N'BOW124BW', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (346, N'ActionLog', CAST(0x0000A75A0119E904 AS DateTime), 3, NULL, N'BOW124BW', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (347, N'ActionLog', CAST(0x0000A75A0153CD63 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (348, N'ActionLog', CAST(0x0000A75A0153DECA AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (349, N'ActionLog', CAST(0x0000A75A0153E236 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (350, N'ActionLog', CAST(0x0000A75A0153E562 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (351, N'ActionLog', CAST(0x0000A75A0153E7C1 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (352, N'ActionLog', CAST(0x0000A75A0153EB30 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (353, N'ActionLog', CAST(0x0000A75A0153EEAF AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (354, N'ActionLog', CAST(0x0000A75A0153F15E AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (355, N'ActionLog', CAST(0x0000A75A0153F3DA AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (356, N'ActionLog', CAST(0x0000A75A0153F733 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (357, N'ActionLog', CAST(0x0000A75A01540242 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (358, N'ActionLog', CAST(0x0000A75A01540A20 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (359, N'ActionLog', CAST(0x0000A75A01542955 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (360, N'ActionLog', CAST(0x0000A75A01546730 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (361, N'ActionLog', CAST(0x0000A75A0154AFFC AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (362, N'ActionLog', CAST(0x0000A75A0154D5AC AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (363, N'ActionLog', CAST(0x0000A75A0154DF25 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (364, N'ActionLog', CAST(0x0000A75A01550291 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (365, N'ActionLog', CAST(0x0000A75A01550525 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (366, N'ActionLog', CAST(0x0000A75A01551DF6 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (367, N'ActionLog', CAST(0x0000A75A015521F0 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (368, N'ActionLog', CAST(0x0000A75A015524D8 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (369, N'ActionLog', CAST(0x0000A75A01552927 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (370, N'ActionLog', CAST(0x0000A75A01552BB3 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (371, N'ActionLog', CAST(0x0000A75A01552FC9 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (372, N'ActionLog', CAST(0x0000A75A015532E8 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (373, N'ActionLog', CAST(0x0000A75A015560FD AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (374, N'ActionLog', CAST(0x0000A75A015563EE AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (375, N'ActionLog', CAST(0x0000A75A01556A84 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (376, N'ActionLog', CAST(0x0000A75A01557064 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (377, N'ActionLog', CAST(0x0000A75A01557371 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (378, N'ActionLog', CAST(0x0000A75A015579D1 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (379, N'ActionLog', CAST(0x0000A75A01557CFB AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (380, N'ActionLog', CAST(0x0000A75A01558055 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (381, N'ActionLog', CAST(0x0000A75A015582FB AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (382, N'ActionLog', CAST(0x0000A75A0155867C AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (383, N'ActionLog', CAST(0x0000A75A01558BE6 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (384, N'ActionLog', CAST(0x0000A75A01558F61 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (385, N'ActionLog', CAST(0x0000A75A01559A9B AS DateTime), 1006, NULL, N'System', N'Mode Changed to Normal')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (386, N'ActionLog', CAST(0x0000A75A01559B8B AS DateTime), 1006, NULL, N'System', N'Mode Changed to Normal')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (387, N'ActionLog', CAST(0x0000A75A01559C99 AS DateTime), 1006, NULL, N'System', N'Mode Changed to Normal')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (388, N'ActionLog', CAST(0x0000A75A0155EC10 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (389, N'ActionLog', CAST(0x0000A75A0155F03C AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (390, N'ActionLog', CAST(0x0000A75A0155F2BC AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (391, N'ActionLog', CAST(0x0000A75A0155F4FA AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (392, N'ActionLog', CAST(0x0000A75A015605A5 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (393, N'ActionLog', CAST(0x0000A75A01560887 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (394, N'ActionLog', CAST(0x0000A75A01560DF1 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (395, N'ActionLog', CAST(0x0000A75A0156952D AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (396, N'ActionLog', CAST(0x0000A75A01569915 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (397, N'ActionLog', CAST(0x0000A75A01569B55 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (398, N'ActionLog', CAST(0x0000A75A01569DD5 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (399, N'ActionLog', CAST(0x0000A75A0156A075 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
GO
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (400, N'ActionLog', CAST(0x0000A75A0156A0A0 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Hotel Room Price Approval')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (401, N'ActionLog', CAST(0x0000A75A0156A2F5 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (402, N'ActionLog', CAST(0x0000A75A0156CA02 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (403, N'ActionLog', CAST(0x0000A75A0157B53C AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (404, N'ActionLog', CAST(0x0000A75A0159E1B0 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (405, N'ActionLog', CAST(0x0000A75A0159EA8C AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (406, N'ActionLog', CAST(0x0000A75A0159EB70 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (407, N'ActionLog', CAST(0x0000A75A0159EC46 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (408, N'ActionLog', CAST(0x0000A75A0159ED05 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (409, N'ActionLog', CAST(0x0000A75A0159EDCA AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (410, N'ActionLog', CAST(0x0000A75A0159EE70 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (411, N'ActionLog', CAST(0x0000A75A0159EF39 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (412, N'ActionLog', CAST(0x0000A75A0159F007 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (413, N'ActionLog', CAST(0x0000A75A0159F0BA AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (414, N'ActionLog', CAST(0x0000A75A0159F5F3 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (415, N'ActionLog', CAST(0x0000A75A0159F7FD AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (416, N'ActionLog', CAST(0x0000A75A0159FA04 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (417, N'ActionLog', CAST(0x0000A75A0159FBBA AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (418, N'ActionLog', CAST(0x0000A75A0159FEDE AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (419, N'ActionLog', CAST(0x0000A75A015A007E AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (420, N'ActionLog', CAST(0x0000A75A015A08F2 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (421, N'ActionLog', CAST(0x0000A75A015A5089 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (422, N'ActionLog', CAST(0x0000A75A015A559A AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (423, N'ActionLog', CAST(0x0000A75A015A58F3 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (424, N'ActionLog', CAST(0x0000A75A015A5D22 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (425, N'ActionLog', CAST(0x0000A75A015A5F52 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (426, N'ActionLog', CAST(0x0000A75A015A60D9 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (427, N'ActionLog', CAST(0x0000A75A015A6284 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (428, N'ActionLog', CAST(0x0000A75A015A64C3 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (429, N'ActionLog', CAST(0x0000A75A015A6C9A AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (430, N'ActionLog', CAST(0x0000A75A015A7364 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (431, N'ActionLog', CAST(0x0000A75A015A76DB AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (432, N'ActionLog', CAST(0x0000A75A015A8338 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (433, N'ActionLog', CAST(0x0000A75A015A853F AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (434, N'ActionLog', CAST(0x0000A75A015A8764 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (435, N'ActionLog', CAST(0x0000A75A015A87CC AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Hotel Room Price Approval')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (436, N'ActionLog', CAST(0x0000A75A015A893F AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (437, N'ActionLog', CAST(0x0000A75A015A8AF4 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (438, N'ActionLog', CAST(0x0000A75A015A8C92 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (439, N'ActionLog', CAST(0x0000A75A015AAA0E AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (440, N'ActionLog', CAST(0x0000A75A015AAB00 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (441, N'ActionLog', CAST(0x0000A75A015AABDB AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (442, N'ActionLog', CAST(0x0000A75A015AAC9F AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (443, N'ActionLog', CAST(0x0000A75A015AAD96 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (444, N'ActionLog', CAST(0x0000A75A015AB2CF AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (445, N'ActionLog', CAST(0x0000A75A015AB5E1 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (446, N'ActionLog', CAST(0x0000A75A015AB74B AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (447, N'ActionLog', CAST(0x0000A75A015ABF90 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (448, N'ActionLog', CAST(0x0000A75A015AC1CD AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (449, N'ActionLog', CAST(0x0000A75A015AC934 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (450, N'ActionLog', CAST(0x0000A75A015AC934 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (451, N'ActionLog', CAST(0x0000A75A015AC95A AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (452, N'ActionLog', CAST(0x0000A75A015AE8D3 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (453, N'ActionLog', CAST(0x0000A75A015BF3E0 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (454, N'ActionLog', CAST(0x0000A75A015C0232 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (455, N'ActionLog', CAST(0x0000A75A015C46AF AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (456, N'ActionLog', CAST(0x0000A75A015CCAD8 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (457, N'ActionLog', CAST(0x0000A75A015CD2F5 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (458, N'ActionLog', CAST(0x0000A75A015CD423 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (459, N'ActionLog', CAST(0x0000A75A015CD486 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (460, N'ActionLog', CAST(0x0000A75A015CD5E3 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (461, N'ActionLog', CAST(0x0000A75A015CDA04 AS DateTime), 5, NULL, N'System', N'Mode Changed to Training')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (462, N'ActionLog', CAST(0x0000A75A015CDB4D AS DateTime), 5, NULL, N'System', N'Mode Changed to Training')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (463, N'ActionLog', CAST(0x0000A75A015CDB86 AS DateTime), 5, NULL, N'System', N'Mode Changed to Training')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (464, N'ActionLog', CAST(0x0000A75A015CDBD5 AS DateTime), 5, NULL, N'System', N'Mode Changed to Training')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (465, N'ActionLog', CAST(0x0000A75A015CDC71 AS DateTime), 5, NULL, N'System', N'Mode Changed to Training')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (466, N'ActionLog', CAST(0x0000A75A015CDD05 AS DateTime), 5, NULL, N'System', N'Mode Changed to Training')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (467, N'ActionLog', CAST(0x0000A75A015CDD80 AS DateTime), 5, NULL, N'System', N'Mode Changed to Normal')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (468, N'ActionLog', CAST(0x0000A75A015CE9DB AS DateTime), 5, NULL, N'System', N'Mode Changed to Training')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (469, N'ActionLog', CAST(0x0000A75A015CEB45 AS DateTime), 5, NULL, N'System', N'Mode Changed to Training')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (470, N'ActionLog', CAST(0x0000A75A015CEC4E AS DateTime), 5, NULL, N'System', N'Mode Changed to Normal')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (471, N'ActionLog', CAST(0x0000A75A015CED31 AS DateTime), 5, NULL, N'System', N'Mode Changed to Training')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (472, N'ActionLog', CAST(0x0000A75A015CEDAA AS DateTime), 5, NULL, N'System', N'Mode Changed to Normal')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (473, N'ActionLog', CAST(0x0000A75A015CEE2B AS DateTime), 5, NULL, N'System', N'Mode Changed to Training')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (474, N'ActionLog', CAST(0x0000A75A015CEE85 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (475, N'ActionLog', CAST(0x0000A75A015CEF0D AS DateTime), 5, NULL, N'System', N'Mode Changed to Training')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (476, N'ActionLog', CAST(0x0000A75A015CEF39 AS DateTime), 5, NULL, N'System', N'Mode Changed to Training')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (477, N'ActionLog', CAST(0x0000A75A015CF8F0 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Hotel Room Price Approval')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (478, N'ActionLog', CAST(0x0000A75A015D086B AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (479, N'ActionLog', CAST(0x0000A75A015F1CB7 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (480, N'ActionLog', CAST(0x0000A75A0163950C AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (481, N'ActionLog', CAST(0x0000A75A01639C47 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (482, N'ActionLog', CAST(0x0000A75A0163A20E AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (483, N'ActionLog', CAST(0x0000A75A016586A3 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (484, N'ActionLog', CAST(0x0000A75A016669A3 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (485, N'ActionLog', CAST(0x0000A75A016B2875 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (486, N'ActionLog', CAST(0x0000A75A016E81C2 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (487, N'ActionLog', CAST(0x0000A75A016E922D AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (488, N'ActionLog', CAST(0x0000A75A016ECA06 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (489, N'ActionLog', CAST(0x0000A75A016F018C AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (490, N'ActionLog', CAST(0x0000A75A016F163D AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (491, N'ActionLog', CAST(0x0000A75A016F2200 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (492, N'ActionLog', CAST(0x0000A75A016F283C AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (493, N'ActionLog', CAST(0x0000A75A016F38D7 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (494, N'ActionLog', CAST(0x0000A75A016F4999 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (495, N'ActionLog', CAST(0x0000A75A016F794F AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (496, N'ActionLog', CAST(0x0000A75A016F94E5 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (497, N'ActionLog', CAST(0x0000A75A016F94EE AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (498, N'ActionLog', CAST(0x0000A75A016FD5FB AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (499, N'ActionLog', CAST(0x0000A75A016FF537 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
GO
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (500, N'ActionLog', CAST(0x0000A75A0170A4EF AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (501, N'ActionLog', CAST(0x0000A75A0170DC27 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (502, N'ActionLog', CAST(0x0000A75A0171013F AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (503, N'ActionLog', CAST(0x0000A75A01711CF0 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (504, N'ActionLog', CAST(0x0000A75A0171241F AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (505, N'ActionLog', CAST(0x0000A75A0171B278 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (506, N'ActionLog', CAST(0x0000A75A01720BB7 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (507, N'ActionLog', CAST(0x0000A75A01721D99 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (508, N'ActionLog', CAST(0x0000A75A017220DF AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (509, N'ActionLog', CAST(0x0000A75A01722E25 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (510, N'ActionLog', CAST(0x0000A75A0172420A AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (511, N'ActionLog', CAST(0x0000A75A01724B10 AS DateTime), 1006, NULL, N'DESKTOP-OVQPAJF', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (512, N'ActionLog', CAST(0x0000A75A01757114 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (513, N'ActionLog', CAST(0x0000A75A017575EB AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (514, N'ErrorLog', CAST(0x0000A75D00C6313A AS DateTime), 1021, N'Fatal Error! Someone set up us the bomb!', NULL, NULL)
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (515, N'ActionLog', CAST(0x0000A75A0175C09A AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (516, N'ActionLog', CAST(0x0000A75D00C63097 AS DateTime), 1021, NULL, N'PLAYSTATION2', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (517, N'ActionLog', CAST(0x0000A75A0176027F AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (518, N'ActionLog', CAST(0x0000A75A0176AB88 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (519, N'ActionLog', CAST(0x0000A75A0176B208 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (520, N'ActionLog', CAST(0x0000A75A0176D9B4 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (521, N'ActionLog', CAST(0x0000A75A01785594 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (522, N'ActionLog', CAST(0x0000A75A01785EA5 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (523, N'ActionLog', CAST(0x0000A75A017E0C90 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (524, N'ActionLog', CAST(0x0000A75A017E1E9B AS DateTime), 3, N'Checked in Blake Warrington', N'SURFACEBOOK', N'Checked in a Guest')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (525, N'ActionLog', CAST(0x0000A75A013CB24F AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (526, N'ActionLog', CAST(0x0000A75A013D89F5 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (527, N'ActionLog', CAST(0x0000A75A013E0250 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (528, N'ActionLog', CAST(0x0000A75A013E77DE AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (529, N'ActionLog', CAST(0x0000A75A013E9E9D AS DateTime), 3, N'Checked in Blake Warrington', N'SURFACEBOOK', N'Checked in a Guest')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (530, N'ActionLog', CAST(0x0000A75A01870495 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (531, N'ActionLog', CAST(0x0000A75A01871916 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (532, N'ActionLog', CAST(0x0000A75A01873FB3 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (533, N'ActionLog', CAST(0x0000A75A01878C3E AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (534, N'ActionLog', CAST(0x0000A75A0187DFB3 AS DateTime), 5, NULL, N'WIN-3GD90E9FQ98', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (535, N'ActionLog', CAST(0x0000A75B00210ED1 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (536, N'ErrorLog', CAST(0x0000A75B0022A75A AS DateTime), NULL, N'User Requested Non-Existent Function', NULL, NULL)
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (537, N'ErrorLog', CAST(0x0000A75B0022ADF4 AS DateTime), NULL, N'User Requested Non-Existent Function', NULL, NULL)
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (538, N'ActionLog', CAST(0x0000A75B0022BB4E AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (539, N'ActionLog', CAST(0x0000A75B0022BC8B AS DateTime), 3, NULL, N'System', N'Mode Changed to Kiosk')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (540, N'ActionLog', CAST(0x0000A75B0022C078 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (541, N'ActionLog', CAST(0x0000A75B0022C090 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (542, N'ActionLog', CAST(0x0000A75B00231684 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (543, N'ActionLog', CAST(0x0000A75B002330C9 AS DateTime), 3, N'Checked in Blake Warrington', N'SURFACEBOOK', N'Checked in a Guest')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (544, N'ActionLog', CAST(0x0000A75B002374FA AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (545, N'ActionLog', CAST(0x0000A75B00238850 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (546, N'ActionLog', CAST(0x0000A75B00258AE8 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (547, N'ActionLog', CAST(0x0000A75B00258EA4 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (548, N'ActionLog', CAST(0x0000A75B00272E3B AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (549, N'ActionLog', CAST(0x0000A75B00278140 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (550, N'ActionLog', CAST(0x0000A75B0027B5ED AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (551, N'ActionLog', CAST(0x0000A75B0028147D AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (552, N'ActionLog', CAST(0x0000A75B00281C2B AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (553, N'ActionLog', CAST(0x0000A75B00282F5A AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (554, N'ActionLog', CAST(0x0000A75B0029BD3A AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (555, N'ActionLog', CAST(0x0000A75B002A00AE AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (556, N'ActionLog', CAST(0x0000A75B002A11DE AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (557, N'ActionLog', CAST(0x0000A75B002A192A AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (558, N'ActionLog', CAST(0x0000A75B002A6397 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (559, N'ActionLog', CAST(0x0000A75B002A84F6 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (560, N'ActionLog', CAST(0x0000A75B002A92CD AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (561, N'ActionLog', CAST(0x0000A75B002AB7A6 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (562, N'ActionLog', CAST(0x0000A75B002AC34D AS DateTime), 3, NULL, N'SURFACEBOOK', N'Logout')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (563, N'ActionLog', CAST(0x0000A75B002AF740 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
INSERT [dbo].[Log] ([log_id], [log_type], [occured_at], [employee_id], [message], [workstation], [event]) VALUES (564, N'ActionLog', CAST(0x0000A75B002D2C93 AS DateTime), 3, NULL, N'SURFACEBOOK', N'Login')
SET IDENTITY_INSERT [dbo].[Log] OFF
INSERT [dbo].[LogType] ([log_type], [description]) VALUES (N'ActionLog', N'Log of every user action')
INSERT [dbo].[LogType] ([log_type], [description]) VALUES (N'ErrorLog', N'Fatal errors that the system encounters')
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'ApproveRoomStatus', N'Approve Room Status', 3)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'CanAddEmployee', N'Can Add an Employee', 9)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'CanApproveSuggestedRoomRate', N'Can Approve Suggested Room Rate', 9)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'CancelHousekeepingRequest', N'Cancel Housekeeping Request', 1)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'CancelMaintenanceRequest', N'Cancel Maintenance Request', 1)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'CanChangeDigitalSignage', N'Can Change Digital Signage', 7)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'CanChangeDigitalSignageVolume', N'Can Change Digital Signage Volume', 7)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'CanEditEmployee', N'Can Edit an Employee', 9)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'CanGrantPermission', N'Can Grant Permission', 9)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'CanLockKioskOnOff', N'Can Lock Kiosk On and Off', 9)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'CanOverrideRoomPrice', N'Can Override Room Price', 9)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'CanRemoveEmployee', N'Can Remove an Employee', 9)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'CanRestartServer', N'Can Restart Server', 10)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'CanRevokePermission', N'Can Revoke Permission', 9)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'CanTurnDigitalSignageOnOff', N'Can Turn Digital Signage On and Off', 9)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'CanUpdateSoftware', N'Can Update Software', 11)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'CanViewFrontDeskAgentAndBelowUserInfo', N'Can View Up To Front Desk User Info', 9)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'CanViewHouseKeepingInfo', N'Can View House Keeping Info', 4)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'CanViewLog', N'Can View Log', 10)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'CanViewMaintenanceInfo', N'Can View Maintenance Info', 6)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'CanViewManagerAndBelowUserInfo', N'Can View Manager and Below User Info', 10)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'ChangeKioskOnOff', N'Change Kiosk On and Off', 7)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'ChangeMaintenanceStatus', N'Change Maintenance Status', 5)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'ChangeRoomStatus', N'Change Room Status', 2)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'ChangeTrainingOnOff', N'Change Training On and Off', 10)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'CheckInGuest', N'Check In Guest', 7)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'CheckOutGuest', N'Check Out Guest', 7)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'CheckRoomStatus', N'Check Room Status', 7)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'HasFullSystemAccess', N'Has Full System Access', 12)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'HouseKeepingReportAdd', N'Allow Adding Housekeeping Report', 4)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'HouseKeepingReportDelete', N'Allow Deleting Housekeeping Report', 4)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'HouseKeepingReportModify', N'Allow Modifying Housekeeping Report', 4)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'MaintenanceReportAdd', N'Maintenance Report Add', 6)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'MaintenanceReportDelete', N'Maintenance Report Delete', 6)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'MaintenanceReportModify', N'Maintenance Report Modify', 6)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'OverrideRoomStatus', N'Override Room Status', 9)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'RequestHousekeeping', N'Request Housekeeping', 1)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'RequestMaintenance', N'Request Maintenance', 1)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'UseConcergieServices', N'Use Concierge Services', 7)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'ViewAccountingInformation', N'View Accounting Information', 8)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'ViewHousekeepingReport', N'View Housekeeping Report', 4)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'ViewMaintenanceReport', N'View Maintenance Report', 6)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'ViewStatistics', N'View Statistics', 8)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'WriteEmployeeCard', N'Write Employee Card', 7)
INSERT [dbo].[Permission] ([permission_name], [description], [access_level]) VALUES (N'WriteGuestCard', N'Write Guest Card', 7)
SET IDENTITY_INSERT [dbo].[Reservation] ON 

INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (1, 3, CAST(0x0000A75A00735B40 AS DateTime), CAST(0x0000A7C400C5C100 AS DateTime), 1, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (2, 12, CAST(0x0000A7B901499700 AS DateTime), CAST(0x0000A7E20083D600 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (3, 15, CAST(0x0000A7B901499700 AS DateTime), CAST(0x0000A7E20083D600 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (8, 22, CAST(0x0000A77E0128A180 AS DateTime), CAST(0x0000A78600A4CB80 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (11, 99, CAST(0x0000A7920128A180 AS DateTime), CAST(0x0000A79400B54640 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (12, 99, CAST(0x0000A7920128A180 AS DateTime), CAST(0x0000A79400A4CB80 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (13, 55, CAST(0x0000A79300C5C100 AS DateTime), CAST(0x0000A79400B54640 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (14, 47, CAST(0x0000A79500C5C100 AS DateTime), CAST(0x0000A79600C5C100 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (15, 94, CAST(0x0000A76000000000 AS DateTime), CAST(0x0000A77D00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (16, 41, CAST(0x0000A7B700000000 AS DateTime), CAST(0x0000A7CD00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (17, 97, CAST(0x0000A6F100000000 AS DateTime), CAST(0x0000A6F400000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (18, 19, CAST(0x0000A72A00000000 AS DateTime), CAST(0x0000A73000000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (19, 93, CAST(0x0000A7A600000000 AS DateTime), CAST(0x0000A7C200000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (20, 98, CAST(0x0000A75200000000 AS DateTime), CAST(0x0000A76C00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (21, 89, CAST(0x0000A75C00000000 AS DateTime), CAST(0x0000A76E00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (22, 50, CAST(0x0000A76B00000000 AS DateTime), CAST(0x0000A78900000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (23, 99, CAST(0x0000A7C300000000 AS DateTime), CAST(0x0000A7CF00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (24, 66, CAST(0x0000A7C400000000 AS DateTime), CAST(0x0000A7C700000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (25, 69, CAST(0x0000A77600000000 AS DateTime), CAST(0x0000A79200000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (26, 96, CAST(0x0000A7BA00000000 AS DateTime), CAST(0x0000A7CD00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (27, 14, CAST(0x0000A75400000000 AS DateTime), CAST(0x0000A76000000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (28, 73, CAST(0x0000A79300000000 AS DateTime), CAST(0x0000A7A500000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (29, 88, CAST(0x0000A72900000000 AS DateTime), CAST(0x0000A72D00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (30, 68, CAST(0x0000A7C500000000 AS DateTime), CAST(0x0000A7DB00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (31, 83, CAST(0x0000A73900000000 AS DateTime), CAST(0x0000A75600000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (32, 64, CAST(0x0000A7A900000000 AS DateTime), CAST(0x0000A7C400000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (33, 82, CAST(0x0000A70A00000000 AS DateTime), CAST(0x0000A70C00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (34, 35, CAST(0x0000A7C600000000 AS DateTime), CAST(0x0000A7CE00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (35, 88, CAST(0x0000A7A700000000 AS DateTime), CAST(0x0000A7BB00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (36, 29, CAST(0x0000A71E00000000 AS DateTime), CAST(0x0000A72400000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (37, 69, CAST(0x0000A78800000000 AS DateTime), CAST(0x0000A7A200000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (38, 86, CAST(0x0000A77300000000 AS DateTime), CAST(0x0000A78B00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (39, 1, CAST(0x0000A75B00000000 AS DateTime), CAST(0x0000A77200000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (40, 75, CAST(0x0000A78C00000000 AS DateTime), CAST(0x0000A79100000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (41, 6, CAST(0x0000A78E00000000 AS DateTime), CAST(0x0000A79600000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (42, 73, CAST(0x0000A76000000000 AS DateTime), CAST(0x0000A76C00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (43, 29, CAST(0x0000A75600000000 AS DateTime), CAST(0x0000A76200000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (44, 54, CAST(0x0000A75000000000 AS DateTime), CAST(0x0000A76D00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (45, 20, CAST(0x0000A78B00000000 AS DateTime), CAST(0x0000A79900000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (46, 69, CAST(0x0000A70200000000 AS DateTime), CAST(0x0000A70400000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (47, 92, CAST(0x0000A79E00000000 AS DateTime), CAST(0x0000A7B400000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (48, 16, CAST(0x0000A77F00000000 AS DateTime), CAST(0x0000A78000000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (49, 10, CAST(0x0000A74900000000 AS DateTime), CAST(0x0000A76400000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (50, 59, CAST(0x0000A78C00000000 AS DateTime), CAST(0x0000A79F00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (51, 95, CAST(0x0000A73300000000 AS DateTime), CAST(0x0000A74800000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (52, 8, CAST(0x0000A72C00000000 AS DateTime), CAST(0x0000A74800000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (53, 27, CAST(0x0000A6F000000000 AS DateTime), CAST(0x0000A6FF00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (54, 82, CAST(0x0000A7C600000000 AS DateTime), CAST(0x0000A7DE00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (55, 94, CAST(0x0000A7B100000000 AS DateTime), CAST(0x0000A7B200000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (56, 33, CAST(0x0000A6F600000000 AS DateTime), CAST(0x0000A70F00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (57, 57, CAST(0x0000A7B900000000 AS DateTime), CAST(0x0000A7CA00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (58, 62, CAST(0x0000A72900000000 AS DateTime), CAST(0x0000A74000000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (59, 63, CAST(0x0000A76E00000000 AS DateTime), CAST(0x0000A76F00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (60, 15, CAST(0x0000A6F600000000 AS DateTime), CAST(0x0000A70300000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (61, 90, CAST(0x0000A71E00000000 AS DateTime), CAST(0x0000A71F00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (62, 98, CAST(0x0000A70100000000 AS DateTime), CAST(0x0000A70200000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (63, 34, CAST(0x0000A72300000000 AS DateTime), CAST(0x0000A73B00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (64, 52, CAST(0x0000A71600000000 AS DateTime), CAST(0x0000A72900000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (65, 22, CAST(0x0000A72900000000 AS DateTime), CAST(0x0000A73900000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (66, 11, CAST(0x0000A7A100000000 AS DateTime), CAST(0x0000A7B200000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (67, 95, CAST(0x0000A72800000000 AS DateTime), CAST(0x0000A73000000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (68, 95, CAST(0x0000A7A900000000 AS DateTime), CAST(0x0000A7AD00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (69, 41, CAST(0x0000A72A00000000 AS DateTime), CAST(0x0000A72F00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (70, 49, CAST(0x0000A78300000000 AS DateTime), CAST(0x0000A79600000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (71, 2, CAST(0x0000A74900000000 AS DateTime), CAST(0x0000A75500000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (72, 14, CAST(0x0000A7C800000000 AS DateTime), CAST(0x0000A7D000000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (73, 70, CAST(0x0000A77100000000 AS DateTime), CAST(0x0000A78400000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (74, 2, CAST(0x0000A74600000000 AS DateTime), CAST(0x0000A75B00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (75, 48, CAST(0x0000A7AA00000000 AS DateTime), CAST(0x0000A7C800000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (76, 30, CAST(0x0000A79200000000 AS DateTime), CAST(0x0000A79300000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (77, 48, CAST(0x0000A74C00000000 AS DateTime), CAST(0x0000A75800000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (78, 6, CAST(0x0000A6F400000000 AS DateTime), CAST(0x0000A70B00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (79, 88, CAST(0x0000A79200000000 AS DateTime), CAST(0x0000A7AD00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (80, 39, CAST(0x0000A70200000000 AS DateTime), CAST(0x0000A70D00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (81, 59, CAST(0x0000A75300000000 AS DateTime), CAST(0x0000A75600000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (82, 39, CAST(0x0000A74F00000000 AS DateTime), CAST(0x0000A76D00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (83, 52, CAST(0x0000A7C500000000 AS DateTime), CAST(0x0000A7C700000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (84, 41, CAST(0x0000A75300000000 AS DateTime), CAST(0x0000A75A00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (85, 7, CAST(0x0000A7C000000000 AS DateTime), CAST(0x0000A7DA00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (86, 16, CAST(0x0000A74000000000 AS DateTime), CAST(0x0000A74F00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (87, 43, CAST(0x0000A6F800000000 AS DateTime), CAST(0x0000A70800000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (88, 71, CAST(0x0000A6FD00000000 AS DateTime), CAST(0x0000A6FE00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (89, 82, CAST(0x0000A7A100000000 AS DateTime), CAST(0x0000A7B200000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (90, 38, CAST(0x0000A74700000000 AS DateTime), CAST(0x0000A74F00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (91, 87, CAST(0x0000A72200000000 AS DateTime), CAST(0x0000A73B00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (92, 96, CAST(0x0000A72E00000000 AS DateTime), CAST(0x0000A73700000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (93, 45, CAST(0x0000A72400000000 AS DateTime), CAST(0x0000A74200000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (94, 92, CAST(0x0000A78D00000000 AS DateTime), CAST(0x0000A79500000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (95, 58, CAST(0x0000A78200000000 AS DateTime), CAST(0x0000A79100000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (96, 25, CAST(0x0000A7C400000000 AS DateTime), CAST(0x0000A7CF00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (97, 98, CAST(0x0000A70700000000 AS DateTime), CAST(0x0000A71C00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (98, 26, CAST(0x0000A6F200000000 AS DateTime), CAST(0x0000A6FC00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (99, 83, CAST(0x0000A74300000000 AS DateTime), CAST(0x0000A75300000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (100, 99, CAST(0x0000A72E00000000 AS DateTime), CAST(0x0000A74500000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (101, 82, CAST(0x0000A70C00000000 AS DateTime), CAST(0x0000A70D00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (102, 25, CAST(0x0000A71800000000 AS DateTime), CAST(0x0000A72100000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (103, 54, CAST(0x0000A71700000000 AS DateTime), CAST(0x0000A72000000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (104, 88, CAST(0x0000A78B00000000 AS DateTime), CAST(0x0000A78D00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (105, 76, CAST(0x0000A73600000000 AS DateTime), CAST(0x0000A74700000000 AS DateTime), 0, 0)
GO
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (106, 72, CAST(0x0000A78900000000 AS DateTime), CAST(0x0000A79400000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (107, 3, CAST(0x0000A71E00000000 AS DateTime), CAST(0x0000A72200000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (108, 46, CAST(0x0000A71E00000000 AS DateTime), CAST(0x0000A72D00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (109, 9, CAST(0x0000A77F00000000 AS DateTime), CAST(0x0000A79200000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (110, 52, CAST(0x0000A76F00000000 AS DateTime), CAST(0x0000A78000000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (111, 20, CAST(0x0000A72E00000000 AS DateTime), CAST(0x0000A73C00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (112, 55, CAST(0x0000A72200000000 AS DateTime), CAST(0x0000A72E00000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (113, 12, CAST(0x0000A7A500000000 AS DateTime), CAST(0x0000A7C000000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (114, 99, CAST(0x0000A6F000000000 AS DateTime), CAST(0x0000A70400000000 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (116, 3, CAST(0x00009B360041EB00 AS DateTime), CAST(0x00009BA9016A8C80 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (117, 3, CAST(0x00009B360041EB00 AS DateTime), CAST(0x00009BA9016A8C80 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (121, 98, CAST(0x0000A05C0128A180 AS DateTime), CAST(0x0000A06400A4CB80 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (122, 3, CAST(0x00009B360041EB00 AS DateTime), CAST(0x00009BA9016A8C80 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (126, 101, CAST(0x000063F00041EB00 AS DateTime), CAST(0x000063F00062E080 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (127, 101, CAST(0x000063F00041EB00 AS DateTime), CAST(0x000063F00062E080 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (128, 101, CAST(0x000063F00041EB00 AS DateTime), CAST(0x000063F00062E080 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (129, 101, CAST(0x000063F00041EB00 AS DateTime), CAST(0x000063F00062E080 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (130, 101, CAST(0x000063F00041EB00 AS DateTime), CAST(0x000063F00062E080 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (133, 101, CAST(0x000063EA00000000 AS DateTime), CAST(0x000063EA00317040 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (147, 101, CAST(0x0000A758016A8C80 AS DateTime), CAST(0x0000A75B016A8C80 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (148, 101, CAST(0x0000A758016A8C80 AS DateTime), CAST(0x0000A75B016A8C80 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (149, 102, CAST(0x0000A77D016A8C80 AS DateTime), CAST(0x0000A780016A8C80 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (150, 102, CAST(0x0000A77C016A8C80 AS DateTime), CAST(0x0000A77F016A8C80 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (152, 103, CAST(0x0000A7DA016A8C80 AS DateTime), CAST(0x0000A7DE016A8C80 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (153, 103, CAST(0x0000A7D9016A8C80 AS DateTime), CAST(0x0000A7DD016A8C80 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (154, 103, CAST(0x0000A7DA016A8C80 AS DateTime), CAST(0x0000A7DE016A8C80 AS DateTime), 0, 0)
INSERT [dbo].[Reservation] ([reservation_number], [guest_id], [start_date], [end_date], [checked_in], [checked_out]) VALUES (155, 103, CAST(0x0000A7DA016A8C80 AS DateTime), CAST(0x0000A7DE016A8C80 AS DateTime), 0, 0)
SET IDENTITY_INSERT [dbo].[Reservation] OFF
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'101     ', N'Double', 10, NULL)
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'102     ', N'Single', 4, NULL)
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'103     ', N'Single', 4, NULL)
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'104     ', N'Double', 10, NULL)
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'105     ', N'Double', 12, NULL)
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'106     ', N'Double', 12, NULL)
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'107     ', N'Single', 6, NULL)
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'108     ', N'Single', 6, NULL)
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'109     ', N'Single', 4, NULL)
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'110     ', N'Double Double', 12, NULL)
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'111     ', N'Double Double', 12, NULL)
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'112     ', N'Double', 13, NULL)
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'113     ', N'Double', 12, CAST(0x0000A75400000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'114     ', N'Single', 5, CAST(0x0000A75500000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'115     ', N'Double', 14, CAST(0x0000A71700000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'116     ', N'Double', 16, CAST(0x0000A72500000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'117     ', N'Single', 6, CAST(0x0000A72D00000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'118     ', N'Single', 5, CAST(0x0000A71700000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'119     ', N'Single', 5, CAST(0x0000A6F800000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'120     ', N'Single', 7, CAST(0x0000A6F600000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'121     ', N'Single', 6, CAST(0x0000A70E00000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'122     ', N'Single', 7, CAST(0x0000A70C00000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'123     ', N'Double', 16, CAST(0x0000A70C00000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'124     ', N'Single', 7, CAST(0x0000A73500000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'125     ', N'Single', 6, CAST(0x0000A75500000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'126     ', N'Family Suite', 20, CAST(0x0000A73E00000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'127     ', N'Family Suite', 20, CAST(0x0000A76100000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'128     ', N'Single', 7, CAST(0x0000A74200000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'129     ', N'Single', 5, CAST(0x0000A72C00000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'130     ', N'Single', 6, CAST(0x0000A70B00000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'131     ', N'Double Double', 18, CAST(0x0000A6F100000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'201     ', N'Double', 12, CAST(0x0000A75A00000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'202     ', N'Single', 6, CAST(0x0000A73500000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'203     ', N'Family Suite', 20, CAST(0x0000A6F200000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'204     ', N'Single', 5, CAST(0x0000A74600000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'205     ', N'Single', 7, CAST(0x0000A6FC00000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'206     ', N'Family Suite', 20, CAST(0x0000A71700000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'207     ', N'Single', 7, CAST(0x0000A71B00000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'208     ', N'Family Suite', 20, CAST(0x0000A74D00000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'209     ', N'Single', 6, CAST(0x0000A72F00000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'210     ', N'Single', 6, CAST(0x0000A71A00000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'211     ', N'Single', 6, CAST(0x0000A72E00000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'212     ', N'Single', 6, CAST(0x0000A74A00000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'213     ', N'Family Suite', 20, CAST(0x0000A73800000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'214     ', N'Single', 5, CAST(0x0000A70000000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'215     ', N'Double', 14, CAST(0x0000A71300000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'216     ', N'Single', 5, CAST(0x0000A72200000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'217     ', N'Single', 6, CAST(0x0000A70D00000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'218     ', N'Double Double', 18, CAST(0x0000A75B00000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'219     ', N'Double', 14, CAST(0x0000A71100000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'220     ', N'Double', 16, CAST(0x0000A73300000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'221     ', N'Single', 6, CAST(0x0000A73F00000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'301     ', N'Double', 14, CAST(0x0000A6F600000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'302     ', N'Double', 12, CAST(0x0000A71F00000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'303     ', N'Single', 5, CAST(0x0000A75500000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'304     ', N'Single', 7, CAST(0x0000A6F600000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'305     ', N'Double', 14, CAST(0x0000A75E00000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'306     ', N'Single', 5, CAST(0x0000A70300000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'307     ', N'Single', 6, CAST(0x0000A75A00000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'308     ', N'Family Suite', 20, CAST(0x0000A70400000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'309     ', N'Double', 14, CAST(0x0000A6FC00000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'310     ', N'Double Double', 18, CAST(0x0000A73300000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'311     ', N'Single', 6, CAST(0x0000A6F600000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'312     ', N'Double', 14, CAST(0x0000A71A00000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'313     ', N'Single', 7, CAST(0x0000A73000000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'314     ', N'Double', 16, CAST(0x0000A71300000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'315     ', N'Double Double', 18, CAST(0x0000A71800000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'316     ', N'Single', 6, CAST(0x0000A74900000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'317     ', N'Family Suite', 20, CAST(0x0000A73000000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'318     ', N'Family Suite', 20, CAST(0x0000A6FF00000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'319     ', N'Double', 12, CAST(0x0000A72B00000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'320     ', N'Family Suite', 20, CAST(0x0000A75900000000 AS DateTime))
INSERT [dbo].[Room] ([room_number], [room_type], [max_occupancy], [last_cleaned]) VALUES (N'321     ', N'Single', 5, CAST(0x0000A71900000000 AS DateTime))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (1, N'101     ', CAST(2480.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (1, N'102     ', CAST(1550.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (1, N'103     ', CAST(1550.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (1, N'104     ', CAST(2480.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (1, N'105     ', CAST(2480.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (2, N'107     ', CAST(2050.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (2, N'108     ', CAST(2050.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (2, N'110     ', CAST(4100.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (2, N'111     ', CAST(4100.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (3, N'109     ', CAST(2050.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (8, N'101     ', CAST(640.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (8, N'102     ', CAST(400.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (8, N'103     ', CAST(400.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (8, N'111     ', CAST(800.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (11, N'101     ', CAST(160.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (11, N'102     ', CAST(100.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (11, N'103     ', CAST(100.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (12, N'107     ', CAST(100.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (13, N'108     ', CAST(50.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (14, N'102     ', CAST(50.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (15, N'110     ', CAST(2900.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (15, N'111     ', CAST(2900.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (15, N'131     ', CAST(2900.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (16, N'106     ', CAST(1760.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (17, N'110     ', CAST(300.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (17, N'111     ', CAST(300.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (17, N'131     ', CAST(300.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (18, N'101     ', CAST(480.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (19, N'131     ', CAST(2800.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (19, N'218     ', CAST(2800.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (19, N'310     ', CAST(2800.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (20, N'101     ', CAST(2080.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (21, N'102     ', CAST(900.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (22, N'107     ', CAST(1500.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (23, N'114     ', CAST(600.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (23, N'131     ', CAST(1200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (24, N'117     ', CAST(150.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (25, N'104     ', CAST(2240.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (26, N'118     ', CAST(950.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (27, N'126     ', CAST(1800.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (28, N'104     ', CAST(1440.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (29, N'102     ', CAST(200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (30, N'102     ', CAST(1100.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (31, N'102     ', CAST(1450.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (32, N'112     ', CAST(2160.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (32, N'113     ', CAST(2160.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (32, N'119     ', CAST(1350.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (32, N'120     ', CAST(1350.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (33, N'101     ', CAST(160.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (34, N'218     ', CAST(800.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (34, N'310     ', CAST(800.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (34, N'315     ', CAST(800.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (35, N'114     ', CAST(1000.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (35, N'315     ', CAST(2000.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (36, N'102     ', CAST(300.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (37, N'126     ', CAST(3900.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (38, N'218     ', CAST(2400.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (38, N'310     ', CAST(2400.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (39, N'103     ', CAST(1150.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (40, N'102     ', CAST(250.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (41, N'109     ', CAST(400.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (41, N'114     ', CAST(400.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (42, N'108     ', CAST(600.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (42, N'218     ', CAST(1200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (43, N'107     ', CAST(600.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (43, N'310     ', CAST(1200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (44, N'104     ', CAST(2320.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (45, N'105     ', CAST(1120.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (45, N'106     ', CAST(1120.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (46, N'102     ', CAST(100.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (47, N'106     ', CAST(1760.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (48, N'110     ', CAST(100.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (49, N'127     ', CAST(4050.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (50, N'117     ', CAST(950.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (51, N'110     ', CAST(2100.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (51, N'111     ', CAST(2100.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (51, N'131     ', CAST(2100.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (52, N'103     ', CAST(1400.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (53, N'102     ', CAST(750.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (54, N'103     ', CAST(1200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (55, N'115     ', CAST(80.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (56, N'103     ', CAST(1250.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (56, N'110     ', CAST(2500.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (57, N'121     ', CAST(850.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (58, N'104     ', CAST(1840.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (59, N'101     ', CAST(80.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (60, N'101     ', CAST(1040.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (61, N'103     ', CAST(50.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (61, N'107     ', CAST(50.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (62, N'104     ', CAST(80.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (63, N'107     ', CAST(1200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (63, N'218     ', CAST(2400.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (64, N'108     ', CAST(950.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (65, N'109     ', CAST(800.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (66, N'107     ', CAST(850.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (67, N'126     ', CAST(1200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (68, N'108     ', CAST(200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (68, N'109     ', CAST(200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (68, N'115     ', CAST(320.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (68, N'116     ', CAST(320.0000 AS Decimal(19, 4)))
GO
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (69, N'105     ', CAST(400.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (70, N'127     ', CAST(2850.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (71, N'103     ', CAST(600.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (71, N'107     ', CAST(600.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (72, N'126     ', CAST(1200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (73, N'105     ', CAST(1520.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (74, N'105     ', CAST(1680.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (75, N'123     ', CAST(2400.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (76, N'108     ', CAST(50.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (76, N'112     ', CAST(80.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (76, N'113     ', CAST(80.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (77, N'203     ', CAST(1800.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (78, N'107     ', CAST(1150.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (79, N'201     ', CAST(2160.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (80, N'108     ', CAST(550.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (81, N'110     ', CAST(300.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (81, N'111     ', CAST(300.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (81, N'131     ', CAST(300.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (82, N'109     ', CAST(1500.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (84, N'106     ', CAST(560.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (85, N'115     ', CAST(2080.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (86, N'108     ', CAST(750.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (86, N'218     ', CAST(1500.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (87, N'109     ', CAST(800.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (87, N'111     ', CAST(1600.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (88, N'108     ', CAST(50.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (89, N'117     ', CAST(850.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (90, N'126     ', CAST(1200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (91, N'114     ', CAST(1250.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (92, N'106     ', CAST(720.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (92, N'112     ', CAST(720.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (93, N'117     ', CAST(1500.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (93, N'310     ', CAST(3000.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (94, N'118     ', CAST(400.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (95, N'108     ', CAST(750.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (95, N'112     ', CAST(1200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (95, N'113     ', CAST(1200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (95, N'119     ', CAST(750.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (96, N'122     ', CAST(550.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (97, N'104     ', CAST(1680.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (98, N'108     ', CAST(500.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (99, N'114     ', CAST(800.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (99, N'117     ', CAST(800.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (100, N'113     ', CAST(1840.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (101, N'105     ', CAST(80.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (102, N'101     ', CAST(720.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (102, N'105     ', CAST(720.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (102, N'109     ', CAST(450.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (102, N'114     ', CAST(450.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (103, N'117     ', CAST(450.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (104, N'103     ', CAST(100.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (105, N'101     ', CAST(1360.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (106, N'115     ', CAST(880.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (107, N'118     ', CAST(200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (108, N'110     ', CAST(1500.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (108, N'119     ', CAST(750.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (109, N'116     ', CAST(1520.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (110, N'108     ', CAST(850.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (111, N'108     ', CAST(700.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (111, N'118     ', CAST(700.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (112, N'120     ', CAST(600.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (114, N'114     ', CAST(1000.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (116, N'101     ', CAST(9200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (116, N'102     ', CAST(5750.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (116, N'104     ', CAST(9200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (116, N'105     ', CAST(9200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (117, N'103     ', CAST(5750.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (117, N'106     ', CAST(9200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (117, N'112     ', CAST(9200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (117, N'113     ', CAST(9200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (121, N'101     ', CAST(640.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (121, N'102     ', CAST(400.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (121, N'103     ', CAST(400.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (121, N'104     ', CAST(640.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (122, N'107     ', CAST(5750.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (122, N'115     ', CAST(9200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (122, N'116     ', CAST(9200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (122, N'123     ', CAST(9200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (126, N'101     ', CAST(0.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (126, N'102     ', CAST(0.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (126, N'110     ', CAST(0.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (126, N'126     ', CAST(0.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (126, N'127     ', CAST(0.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (127, N'103     ', CAST(0.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (127, N'104     ', CAST(0.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (127, N'111     ', CAST(0.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (127, N'203     ', CAST(0.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (127, N'206     ', CAST(0.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (128, N'105     ', CAST(0.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (128, N'107     ', CAST(0.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (128, N'131     ', CAST(0.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (128, N'208     ', CAST(0.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (128, N'213     ', CAST(0.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (129, N'106     ', CAST(0.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (129, N'108     ', CAST(0.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (129, N'218     ', CAST(0.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (129, N'308     ', CAST(0.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (129, N'317     ', CAST(0.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (130, N'109     ', CAST(0.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (130, N'112     ', CAST(0.0000 AS Decimal(19, 4)))
GO
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (130, N'310     ', CAST(0.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (130, N'318     ', CAST(0.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (130, N'320     ', CAST(0.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (133, N'101     ', CAST(0.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (133, N'102     ', CAST(0.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (133, N'110     ', CAST(0.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (133, N'126     ', CAST(0.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (133, N'127     ', CAST(0.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (147, N'108     ', CAST(150.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (147, N'110     ', CAST(300.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (147, N'112     ', CAST(240.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (147, N'203     ', CAST(450.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (147, N'206     ', CAST(450.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (148, N'111     ', CAST(300.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (148, N'113     ', CAST(240.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (148, N'114     ', CAST(150.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (148, N'208     ', CAST(450.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (148, N'213     ', CAST(450.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (149, N'106     ', CAST(240.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (149, N'109     ', CAST(150.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (149, N'126     ', CAST(450.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (149, N'131     ', CAST(300.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (150, N'112     ', CAST(240.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (150, N'114     ', CAST(150.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (150, N'127     ', CAST(450.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (150, N'315     ', CAST(300.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (152, N'101     ', CAST(320.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (152, N'114     ', CAST(200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (152, N'117     ', CAST(200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (152, N'126     ', CAST(600.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (152, N'131     ', CAST(400.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (153, N'104     ', CAST(320.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (153, N'118     ', CAST(200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (153, N'119     ', CAST(200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (153, N'127     ', CAST(600.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (153, N'218     ', CAST(400.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (154, N'105     ', CAST(320.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (154, N'120     ', CAST(200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (154, N'121     ', CAST(200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (154, N'203     ', CAST(600.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (154, N'310     ', CAST(400.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (155, N'106     ', CAST(320.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (155, N'122     ', CAST(200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (155, N'124     ', CAST(200.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (155, N'206     ', CAST(600.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForReservation] ([reservation_number], [room_number], [cost_for_stay]) VALUES (155, N'315     ', CAST(400.0000 AS Decimal(19, 4)))
INSERT [dbo].[RoomForTicket] ([room_number], [ticket_number]) VALUES (N'105     ', 1008)
INSERT [dbo].[RoomForTicket] ([room_number], [ticket_number]) VALUES (N'110     ', 1010)
INSERT [dbo].[RoomForTicket] ([room_number], [ticket_number]) VALUES (N'111     ', 1010)
INSERT [dbo].[RoomForTicket] ([room_number], [ticket_number]) VALUES (N'117     ', 1009)
INSERT [dbo].[RoomForTicket] ([room_number], [ticket_number]) VALUES (N'131     ', 1010)
INSERT [dbo].[RoomType] ([room_type], [cost_per_day], [description], [guest_room], [rentable]) VALUES (N'Double', CAST(80.0000 AS Decimal(19, 4)), N'A room with a double bed', 1, 1)
INSERT [dbo].[RoomType] ([room_type], [cost_per_day], [description], [guest_room], [rentable]) VALUES (N'Double Double', CAST(100.0000 AS Decimal(19, 4)), N'A room with two double beds', 1, 1)
INSERT [dbo].[RoomType] ([room_type], [cost_per_day], [description], [guest_room], [rentable]) VALUES (N'Family Suite', CAST(150.0000 AS Decimal(19, 4)), N'agkl;ajerglak awklg', 1, 1)
INSERT [dbo].[RoomType] ([room_type], [cost_per_day], [description], [guest_room], [rentable]) VALUES (N'Single', CAST(50.0000 AS Decimal(19, 4)), N'A room with a single bed', 1, 1)
SET IDENTITY_INSERT [dbo].[Ticket] ON 

INSERT [dbo].[Ticket] ([ticket_number], [ticket_type], [opened_by], [assigned_to], [closed_by], [title], [description], [date_opened], [date_closed], [priority], [completed]) VALUES (4, N'Housekeeping', NULL, NULL, NULL, N'Clean room 112', N'Do work work', CAST(0x0000A70E00000000 AS DateTime), NULL, NULL, 0)
INSERT [dbo].[Ticket] ([ticket_number], [ticket_type], [opened_by], [assigned_to], [closed_by], [title], [description], [date_opened], [date_closed], [priority], [completed]) VALUES (1004, N'Maintenance', 3, NULL, NULL, N'My Maitenance Ticket', N'This is a ticket to check if this is working.', CAST(0x0000A75A0015FE02 AS DateTime), NULL, NULL, 0)
INSERT [dbo].[Ticket] ([ticket_number], [ticket_type], [opened_by], [assigned_to], [closed_by], [title], [description], [date_opened], [date_closed], [priority], [completed]) VALUES (1005, N'Housekeeping', 3, NULL, NULL, N'My Housekeeping Ticket', N'This is a ticket to check if this is working.', CAST(0x0000A75A00160B64 AS DateTime), NULL, NULL, 0)
INSERT [dbo].[Ticket] ([ticket_number], [ticket_type], [opened_by], [assigned_to], [closed_by], [title], [description], [date_opened], [date_closed], [priority], [completed]) VALUES (1006, N'Housekeeping', NULL, NULL, NULL, N'Yee', N'Tee', CAST(0x0000A75B0025E3CE AS DateTime), NULL, N'2', 0)
INSERT [dbo].[Ticket] ([ticket_number], [ticket_type], [opened_by], [assigned_to], [closed_by], [title], [description], [date_opened], [date_closed], [priority], [completed]) VALUES (1008, N'Housekeeping', NULL, NULL, NULL, N'Clean room after checkout', N'This is an autogenerated ticket to clean room after guest departure.', CAST(0x0000A75B002AF09A AS DateTime), NULL, N'Low', 0)
INSERT [dbo].[Ticket] ([ticket_number], [ticket_type], [opened_by], [assigned_to], [closed_by], [title], [description], [date_opened], [date_closed], [priority], [completed]) VALUES (1009, N'Housekeeping', NULL, NULL, NULL, N'Clean room after checkout', N'This is an autogenerated ticket to clean room after guest departure.', CAST(0x0000A75B002B2EEE AS DateTime), NULL, N'Low', 0)
INSERT [dbo].[Ticket] ([ticket_number], [ticket_type], [opened_by], [assigned_to], [closed_by], [title], [description], [date_opened], [date_closed], [priority], [completed]) VALUES (1010, N'Housekeeping', NULL, NULL, NULL, N'Clean room after checkout', N'This is an autogenerated ticket to clean room after guest departure.', CAST(0x0000A75B002B5EC5 AS DateTime), NULL, N'Low', 0)
SET IDENTITY_INSERT [dbo].[Ticket] OFF
INSERT [dbo].[TicketType] ([ticket_type], [description]) VALUES (N'Housekeeping', N'This ticket type is used for any requests related to cleaning requests')
INSERT [dbo].[TicketType] ([ticket_type], [description]) VALUES (N'Maintenance', N'This ticket type is used for any requests relating to break/fixes, plumbing, electrical')
SET IDENTITY_INSERT [dbo].[Token] ON 

INSERT [dbo].[Token] ([token_id], [token], [creation_date], [employee_id], [expiration_date]) VALUES (1, N'68f2f755c5e1408fb4a1e3c39ba371b3', CAST(0x0000A73700B89200 AS DateTime), NULL, NULL)
INSERT [dbo].[Token] ([token_id], [token], [creation_date], [employee_id], [expiration_date]) VALUES (2, N'3uppd267e44wvz9a2ns79uc8vwtrpt9k', CAST(0x0000A73700B91EA0 AS DateTime), 3, NULL)
INSERT [dbo].[Token] ([token_id], [token], [creation_date], [employee_id], [expiration_date]) VALUES (3, N'r6f4gggxv5z6xnruvzh288x9yk6df467', CAST(0x0000A73700B91EA0 AS DateTime), 5, NULL)
INSERT [dbo].[Token] ([token_id], [token], [creation_date], [employee_id], [expiration_date]) VALUES (4, N'praj8m6xpsv8s68cejt6nwqspn2nyc8k', CAST(0x0000A73A00317040 AS DateTime), 6, NULL)
INSERT [dbo].[Token] ([token_id], [token], [creation_date], [employee_id], [expiration_date]) VALUES (5, N'uqr9f6i24j255rsjgl2c1d6lfuagbnit', CAST(0x0000A74401518E10 AS DateTime), 1006, NULL)
INSERT [dbo].[Token] ([token_id], [token], [creation_date], [employee_id], [expiration_date]) VALUES (11, N'16328cbc44d9431abd9bb63a2dd4cd8e', CAST(0x0000A7550017A27E AS DateTime), 1021, NULL)
INSERT [dbo].[Token] ([token_id], [token], [creation_date], [employee_id], [expiration_date]) VALUES (12, N'd3656729e4ac45b5abc351f91dbf30fe', CAST(0x0000A75501101EF6 AS DateTime), 1022, NULL)
INSERT [dbo].[Token] ([token_id], [token], [creation_date], [employee_id], [expiration_date]) VALUES (1013, N'94b6778ae9bb4b4bae9507bd17eecf06', CAST(0x0000A75801771B0E AS DateTime), 1025, NULL)
SET IDENTITY_INSERT [dbo].[Token] OFF
/****** Object:  Index [IX_Charge]    Script Date: 4/19/2017 7:44:47 PM ******/
ALTER TABLE [dbo].[Charge] ADD  CONSTRAINT [IX_Charge] UNIQUE NONCLUSTERED 
(
	[charge_number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [UQ_Employee_username]    Script Date: 4/19/2017 7:44:47 PM ******/
ALTER TABLE [dbo].[Employee] ADD  CONSTRAINT [UQ_Employee_username] UNIQUE NONCLUSTERED 
(
	[username] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
/****** Object:  Index [UQ_Invoice_reservation_number]    Script Date: 4/19/2017 7:44:47 PM ******/
ALTER TABLE [dbo].[Invoice] ADD  CONSTRAINT [UQ_Invoice_reservation_number] UNIQUE NONCLUSTERED 
(
	[reservation_number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
/****** Object:  Index [UQ_Token_token]    Script Date: 4/19/2017 7:44:47 PM ******/
ALTER TABLE [dbo].[Token] ADD  CONSTRAINT [UQ_Token_token] UNIQUE NONCLUSTERED 
(
	[employee_id] ASC,
	[expiration_date] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Invoice] ADD  DEFAULT ((0)) FOR [paid]
GO
ALTER TABLE [dbo].[Reservation] ADD  DEFAULT ((0)) FOR [checked_in]
GO
ALTER TABLE [dbo].[Reservation] ADD  DEFAULT ((0)) FOR [checked_out]
GO
ALTER TABLE [dbo].[Ticket] ADD  CONSTRAINT [Ticket_GetCurrDate]  DEFAULT (getdate()) FOR [date_opened]
GO
ALTER TABLE [dbo].[Ticket] ADD  CONSTRAINT [DF__Ticket__complete__3493CFA7]  DEFAULT ((0)) FOR [completed]
GO
ALTER TABLE [dbo].[Charge]  WITH CHECK ADD  CONSTRAINT [FK_Charge_Invoice] FOREIGN KEY([invoice_number])
REFERENCES [dbo].[Invoice] ([invoice_number])
GO
ALTER TABLE [dbo].[Charge] CHECK CONSTRAINT [FK_Charge_Invoice]
GO
ALTER TABLE [dbo].[Employee]  WITH CHECK ADD  CONSTRAINT [FK_Employee_JobTitle] FOREIGN KEY([access_level])
REFERENCES [dbo].[JobTitle] ([access_level])
GO
ALTER TABLE [dbo].[Employee] CHECK CONSTRAINT [FK_Employee_JobTitle]
GO
ALTER TABLE [dbo].[EmployeeHasPermission]  WITH CHECK ADD  CONSTRAINT [FK_EmployeeHasPermission_Employee] FOREIGN KEY([employee_id])
REFERENCES [dbo].[Employee] ([employee_id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[EmployeeHasPermission] CHECK CONSTRAINT [FK_EmployeeHasPermission_Employee]
GO
ALTER TABLE [dbo].[EmployeeHasPermission]  WITH CHECK ADD  CONSTRAINT [FK_EmployeeHasPermission_Permission] FOREIGN KEY([permission_name])
REFERENCES [dbo].[Permission] ([permission_name])
GO
ALTER TABLE [dbo].[EmployeeHasPermission] CHECK CONSTRAINT [FK_EmployeeHasPermission_Permission]
GO
ALTER TABLE [dbo].[Invoice]  WITH CHECK ADD  CONSTRAINT [FK_Invoice_Reservation] FOREIGN KEY([reservation_number])
REFERENCES [dbo].[Reservation] ([reservation_number])
GO
ALTER TABLE [dbo].[Invoice] CHECK CONSTRAINT [FK_Invoice_Reservation]
GO
ALTER TABLE [dbo].[Log]  WITH CHECK ADD  CONSTRAINT [FK_Log_Employee] FOREIGN KEY([employee_id])
REFERENCES [dbo].[Employee] ([employee_id])
GO
ALTER TABLE [dbo].[Log] CHECK CONSTRAINT [FK_Log_Employee]
GO
ALTER TABLE [dbo].[Log]  WITH CHECK ADD  CONSTRAINT [FK_Log_LogType] FOREIGN KEY([log_type])
REFERENCES [dbo].[LogType] ([log_type])
GO
ALTER TABLE [dbo].[Log] CHECK CONSTRAINT [FK_Log_LogType]
GO
ALTER TABLE [dbo].[Permission]  WITH CHECK ADD  CONSTRAINT [FK_Permission_JobTitle] FOREIGN KEY([access_level])
REFERENCES [dbo].[JobTitle] ([access_level])
GO
ALTER TABLE [dbo].[Permission] CHECK CONSTRAINT [FK_Permission_JobTitle]
GO
ALTER TABLE [dbo].[Reservation]  WITH CHECK ADD  CONSTRAINT [FK_Reservation_Guest] FOREIGN KEY([guest_id])
REFERENCES [dbo].[Guest] ([guest_id])
GO
ALTER TABLE [dbo].[Reservation] CHECK CONSTRAINT [FK_Reservation_Guest]
GO
ALTER TABLE [dbo].[Room]  WITH CHECK ADD  CONSTRAINT [FK_Room_RoomType] FOREIGN KEY([room_type])
REFERENCES [dbo].[RoomType] ([room_type])
GO
ALTER TABLE [dbo].[Room] CHECK CONSTRAINT [FK_Room_RoomType]
GO
ALTER TABLE [dbo].[RoomForReservation]  WITH CHECK ADD  CONSTRAINT [FK_RoomForReservation_Reservation] FOREIGN KEY([reservation_number])
REFERENCES [dbo].[Reservation] ([reservation_number])
GO
ALTER TABLE [dbo].[RoomForReservation] CHECK CONSTRAINT [FK_RoomForReservation_Reservation]
GO
ALTER TABLE [dbo].[RoomForReservation]  WITH CHECK ADD  CONSTRAINT [FK_RoomForReservation_Room] FOREIGN KEY([room_number])
REFERENCES [dbo].[Room] ([room_number])
GO
ALTER TABLE [dbo].[RoomForReservation] CHECK CONSTRAINT [FK_RoomForReservation_Room]
GO
ALTER TABLE [dbo].[RoomForTicket]  WITH CHECK ADD  CONSTRAINT [FK_RoomForTicket_Room] FOREIGN KEY([room_number])
REFERENCES [dbo].[Room] ([room_number])
GO
ALTER TABLE [dbo].[RoomForTicket] CHECK CONSTRAINT [FK_RoomForTicket_Room]
GO
ALTER TABLE [dbo].[RoomForTicket]  WITH CHECK ADD  CONSTRAINT [FK_RoomForTicket_Ticket] FOREIGN KEY([ticket_number])
REFERENCES [dbo].[Ticket] ([ticket_number])
GO
ALTER TABLE [dbo].[RoomForTicket] CHECK CONSTRAINT [FK_RoomForTicket_Ticket]
GO
ALTER TABLE [dbo].[Ticket]  WITH CHECK ADD  CONSTRAINT [FK_Ticket_Employee_assigned_to] FOREIGN KEY([assigned_to])
REFERENCES [dbo].[Employee] ([employee_id])
GO
ALTER TABLE [dbo].[Ticket] CHECK CONSTRAINT [FK_Ticket_Employee_assigned_to]
GO
ALTER TABLE [dbo].[Ticket]  WITH CHECK ADD  CONSTRAINT [FK_Ticket_Employee_closed_by] FOREIGN KEY([closed_by])
REFERENCES [dbo].[Employee] ([employee_id])
GO
ALTER TABLE [dbo].[Ticket] CHECK CONSTRAINT [FK_Ticket_Employee_closed_by]
GO
ALTER TABLE [dbo].[Ticket]  WITH CHECK ADD  CONSTRAINT [FK_Ticket_Employee_opened_by] FOREIGN KEY([opened_by])
REFERENCES [dbo].[Employee] ([employee_id])
GO
ALTER TABLE [dbo].[Ticket] CHECK CONSTRAINT [FK_Ticket_Employee_opened_by]
GO
ALTER TABLE [dbo].[Ticket]  WITH CHECK ADD  CONSTRAINT [FK_Ticket_TicketType] FOREIGN KEY([ticket_type])
REFERENCES [dbo].[TicketType] ([ticket_type])
GO
ALTER TABLE [dbo].[Ticket] CHECK CONSTRAINT [FK_Ticket_TicketType]
GO
ALTER TABLE [dbo].[Token]  WITH CHECK ADD  CONSTRAINT [FK_Token_Employee] FOREIGN KEY([employee_id])
REFERENCES [dbo].[Employee] ([employee_id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[Token] CHECK CONSTRAINT [FK_Token_Employee]
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "Reservation"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 136
               Right = 232
            End
            DisplayFlags = 280
            TopColumn = 2
         End
         Begin Table = "Room"
            Begin Extent = 
               Top = 6
               Left = 270
               Bottom = 136
               Right = 444
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "RoomForReservation"
            Begin Extent = 
               Top = 6
               Left = 482
               Bottom = 119
               Right = 676
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'BookedRoom'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'BookedRoom'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "Reservation"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 136
               Right = 232
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Guest"
            Begin Extent = 
               Top = 6
               Left = 270
               Bottom = 136
               Right = 440
            End
            DisplayFlags = 280
            TopColumn = 1
         End
         Begin Table = "RoomForReservation"
            Begin Extent = 
               Top = 6
               Left = 478
               Bottom = 119
               Right = 672
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'CheckInList'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'CheckInList'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "Reservation"
            Begin Extent = 
               Top = 4
               Left = 44
               Bottom = 134
               Right = 238
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Guest"
            Begin Extent = 
               Top = 6
               Left = 326
               Bottom = 136
               Right = 496
            End
            DisplayFlags = 280
            TopColumn = 1
         End
         Begin Table = "RoomForReservation"
            Begin Extent = 
               Top = 6
               Left = 534
               Bottom = 119
               Right = 728
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'CheckOutList'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'CheckOutList'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "RoomForTicket"
            Begin Extent = 
               Top = 6
               Left = 246
               Bottom = 102
               Right = 416
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Ticket"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 136
               Right = 208
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'HousekeepingTicketList'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'HousekeepingTicketList'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "RoomForTicket"
            Begin Extent = 
               Top = 10
               Left = 172
               Bottom = 169
               Right = 342
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Ticket"
            Begin Extent = 
               Top = 10
               Left = 387
               Bottom = 311
               Right = 557
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'MaintenanceTicketList'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'MaintenanceTicketList'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "Invoice"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 119
               Right = 212
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Guest"
            Begin Extent = 
               Top = 8
               Left = 435
               Bottom = 138
               Right = 605
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Charge"
            Begin Extent = 
               Top = 154
               Left = 73
               Bottom = 282
               Right = 243
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'OutstandingInvoice'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'OutstandingInvoice'
GO
USE [master]
GO
ALTER DATABASE [GuestBook] SET  READ_WRITE 
GO
