-- Unity Real Time Database Service Pack 4 (version 2.4.3.002) - Created 4:29PM 08/13/15
-- upgrade from 2.4.2.000
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[usp_upd_miscSeq]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].usp_upd_miscSeq
GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

CREATE PROCEDURE [dbo].[usp_upd_miscSeq]
AS
DECLARE @sequence as nvarchar(4)
	SELECT @sequence = description FROM Misc WHERE Name = 'Sequence'
	
	IF (@sequence IS NULL) --Not exists
		INSERT INTO Misc VALUES('Sequence', '1')
	ELSE IF (@sequence = '9999')
		UPDATE Misc SET description = '1' WHERE name = 'Sequence'
	ELSE
		UPDATE Misc SET description = (CONVERT(INT, Description) + 1) WHERE name = 'Sequence'
GO

--This script needs to be run for only version SP 2.4.3
UPDATE Misc SET description = '1' WHERE name = 'Sequence'
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[usp_Check_And_Create_Test]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[usp_Check_And_Create_Test]
GO

CREATE PROCEDURE dbo.usp_Check_And_Create_Test
		@CreateTestOption as tinyint,
		@Point_OR_Summary as tinyint,
		@op as nvarchar(20),
		@LabID as int,
		@LotID as nvarchar(15),
		@AnalyteID as smallint,
		@MethodID as smallint,
		@InstrumentID as smallint,
		@ReagentID as smallint,
		@UnitID as smallint,
		@TemperatureID as smallint,
		@mEnteredDate as datetime OUTPUT,
		@ErrorFlag as tinyint OUTPUT,
		@mLabLotTestID as int OUTPUT,
		@RuleNames as nvarchar(120),
		@LanguageID as nvarchar(10)
		
 AS

	Declare @Count as tinyint
	Declare @Error_Flag as tinyint
	Declare @ExpiredDate as datetime
	Declare @Status as tinyint
	Declare @Levels as tinyint
	Declare @lltEnteredDate as datetime

	Declare @AnalyteName as nvarchar(80)
	Declare @MethodName as nvarchar(80)
	Declare @InstrumentName as nvarchar(80)
	Declare @ReagentName as nvarchar(80)
	Declare @UnitName as nvarchar(80)
	Declare @TemperatureName as nvarchar(80)

	Declare @Analyte_Flag as char(5)
	Declare @Method_Flag as char(5)
	Declare @Instrument_Flag as char(5)
	Declare @Reagent_Flag as char(5)
	Declare @Unit_Flag as char(5)
	Declare @Temperature_Flag as char(5)
	Declare @LabLotTestID as int
	Declare @EnteredDate as datetime
	Declare @SlideGen as tinyint
	Declare @TestID as int
	Declare @strSQL as nvarchar(200)
	Declare @mDate as datetime
	Declare @mDateminus24 as datetime
	Declare @RuleSettingsString as nvarchar(100)
	Declare @LabLotTestInfo as nvarchar(200)
	Declare @SequenceID as int
	Declare @ByteLevelsInUsedMask as int
	Declare @TempReagentID as smallint
	Declare @TestCount as int
	Declare @TestCount1 as int
	Declare @Decimal1 as tinyint, @Decimal2 as tinyint, @Decimal3 as tinyint, @Decimal4 as tinyint, @Decimal5 as tinyint,
			@Decimal6 as tinyint, @Decimal7 as tinyint, @Decimal8 as tinyint, @Decimal9 as tinyint  



--	BEGIN TRANSACTION Create_LabLotTest

	
	Select @AnalyteName = Name, @Analyte_Flag = Flag  From Analyte Where AnalyteID = @AnalyteID
	Select @MethodName = Name, @Method_Flag  = Flag From Method Where MethodID = @MethodID
	Select @InstrumentName = Name, @Instrument_Flag = Flag From Instrument Where InstrumentID = @InstrumentID

	if (@ReagentID >= 1000) And (@ReagentID <= 1099)
	Begin
		SET @SlideGen = @ReagentID - 1000 
		SET @TempReagentID = 1000
		Select @ReagentName = Name, @Reagent_Flag = Flag From Reagent Where ReagentID = @TempReagentID
		SET @ReagentName = Replace(@ReagentName,  '00', @SlideGen)

	End
	Else
	Begin
		Select @ReagentName = Name, @Reagent_Flag = Flag From Reagent Where ReagentID = @ReagentID
	End

	Select @UnitName = Name, @Unit_Flag = flag  From Unit Where UnitID = @UnitID
	Select @TemperatureName = Name, @Temperature_Flag = flag From Temperature Where TemperatureID = @TemperatureID

	Select @ExpiredDate = ExpiredDate, @Levels = Levels  from LabLot Where LabID = @LabID and LotID = @LotID
	
	Select @TestCount1 = ISNULL(Count(*), 0)  FROM Test WHERE AnalyteID = @AnalyteID and MethodID = @MethodID and InstrumentID = @InstrumentID and
		ReagentID = @ReagentID and UnitID = @UnitId and TemperatureID = @TemperatureID 

	SET @TestCount1 = ISNULL(@TestCount1, 0)
	If  (@TestCount1 > 0)
	Begin
		Select @TestID = TestID FROM Test WHERE AnalyteID = @AnalyteID and MethodID = @MethodID and InstrumentID = @InstrumentID and
			ReagentID = @ReagentID and UnitID = @UnitId and TemperatureID = @TemperatureID 

		Select @Count = count(*) from LabLotTest Where LabID = @LabID and LotID = @LotID and TestID = @TestID
	End
	Else
		SET @Count = 0

	if (@Count > 0)
	Begin
		-- 2009/07/21   Vu Fixed
		Select @LabLotTestID = LabLotTestID, @lltEnteredDate = EnteredDate  from LabLotTest Where LabID = @LabID and LotID = @LotID and TestID = @TestID and Status = 1
		SET @LabLotTestID = ISNULL(@LabLotTestID, 0)
		if (@LabLotTestID > 0)
			SET @ErrorFlag = 0
		Else
			SET @ErrorFlag = 2
	End
	else
	begin
		if (@CreateTestOption > 0)
		begin
			Set @TestID = (Select ISNULL(TestID, 0) FROM Test
			WHERE AnalyteID = @AnalyteID and MethodID = @MethodID and InstrumentID = @InstrumentID and
				ReagentID = @ReagentID and UnitID = @UnitId and TemperatureID = @TemperatureID)
			SET @TestID = ISNULL(@TestID, 0)

			if @TestID = 0
			Begin
				Select @TestCount = max(testid) FROM Test
				Set @TestCount = ISNULL(@TestCount, 0)
				if (@TestCount = 0) 
						SET @TestID =  1

				else
						SET @TestID = @TestCount + 1

				Insert INTO Test VALUES (@TestID, @AnalyteID, @InstrumentID, @MethodID, 
					 @ReagentID, @TemperatureID, @UnitID,GetDate(),
					@RuleNames, '2|0|0|0|0|0|0|2|0|0|0|0|0|0|0|0|0|')
				SET @strSQL = 'Add | Test | TestID= ' + str(@TestID)
				INSERT into AuditTransaction VALUES (0, GetDate(), @op, @strSQL)
			End

			Set  @TestCount = (Select  ISNULL(Count(*), 0)  FROM LabLotTest) 
			Set @TestCount = ISNULL(@TestCount, 0)

			IF (@TestCount = 0) 
			Begin
				SET @LabLotTestID = 1
				SET @SequenceID =  1
			End
			Else
			Begin
				Select @LabLotTestID = max(LabLotTestID) + 1 FROM LabLotTest
				Set @SequenceID = (Select ISNULL(max(SequenceID) + 1, 1)  FROM LabLotTest WHERE LabID = @LabID AND LotID = @LotID)
				set @SequenceID = ISNULL(@SequenceID, 1) 

			End
			SET @mDate = GetDate()
			SET @mDateminus24 = DateAdd(year,0, @mDate)
			SET @lltEnteredDate = @mDateminus24
				
			Select @RuleSettingsString = RuleSettingsString FROM LabLot
				WHERE LabId = @LabID and LotID = @LotID

			SET @strSQL = 'Mandelic Acid|HPLC|Roche MODULAR ISE|Dedicated Reagent|mg/L|No Temperature'
			SET @LabLotTestInfo = @AnalyteName + '|' +
					 @MethodName + '|' +
					 @InstrumentName + '|' +
					 @ReagentName + '|' +
					 @UnitName + '|' +
					 @TemperatureName 

			if ( @Levels > 3 )
				SET @ByteLevelsInUsedMask = 15
			else
				SET @ByteLevelsInUsedMask = POWER(2, @Levels) - 1
		
			Select @Decimal1 = Level1Decimal, @Decimal2 = Level2Decimal, @Decimal3 = Level3Decimal,
				@Decimal4 = Level4Decimal, @Decimal5 = Level5Decimal, @Decimal6 = Level6Decimal,
				@Decimal7 = Level7Decimal, @Decimal8 = Level8Decimal, @Decimal9 = Level9Decimal
			FROM LabLot where LabID = @LabID and LotID = @LotID

			Exec LabLotTest_Add_SP @LabLotTestID,  @LabID, @LotID, @TestID , @mDateminus24, @mDate , 0, 0, 20,@ByteLevelsInUsedMask,2,1,
				@RuleNames,
				@RuleSettingsString,
				@Decimal1, @Decimal2, @Decimal3, @Decimal4, @Decimal5,
				@Decimal6, @Decimal7, @Decimal8, @Decimal9, '', @LabLotTestInfo, @Sequenceid, @LanguageID

			SET @strSQL = 'Add | LabLotTest | LabLotTestID=' + str(@LabLotTestID)
			INSERT AuditTransaction VALUES (0, GetDate(), @op, @strSQL)
			-- Remove the redundant ResTestRep because Exec LabLotTest_Add_SP already generates the ResTestRep.  
			
			SET @Count = 1
			SET @ErrorFlag = 0
		end
		else
		Begin
			SET 	@ErrorFlag = 1
			GOTO   GO_EXIT
		End

	
	end


	
GO_EXIT:

		SET @ErrorFlag	 	= 	 ISNULL(@ErrorFlag, 0)
		SET @mLabLotTestID	 	= 	 ISNULL(@LabLotTestID, 0)
		SET @mEnteredDate	 	= 	 ISNULL(@lltEnteredDate, 0)

--	COMMIT TRANSACTION Create_LabLotTest
	RETURN

GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[usp_Check_And_Create_Test1]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[usp_Check_And_Create_Test1]
GO

Create PROCEDURE [dbo].[usp_Check_And_Create_Test1]
		@CreateTestOption as tinyint,
		@Point_OR_Summary as tinyint,
		@op as nvarchar(20),
		@LabID as int,
		@LotID as nvarchar(15),
		@AnalyteID as smallint,
		@MethodID as smallint,
		@InstrumentID as smallint,
		@ReagentID as smallint,
		@UnitID as smallint,
		@TemperatureID as smallint,
		@mEnteredDate as datetime OUTPUT,
		@ErrorFlag as tinyint OUTPUT,
		@mLabLotTestID as int OUTPUT,
		@RuleNames as nvarchar(120),
		@LanguageID as nvarchar(10)
		
 AS

	Declare @Count as tinyint
	Declare @Error_Flag as tinyint
	Declare @ExpiredDate as datetime
	Declare @Status as tinyint
	Declare @Levels as tinyint
	Declare @lltEnteredDate as datetime

	Declare @AnalyteName as nvarchar(80)
	Declare @MethodName as nvarchar(80)
	Declare @InstrumentName as nvarchar(80)
	Declare @ReagentName as nvarchar(80)
	Declare @UnitName as nvarchar(80)
	Declare @TemperatureName as nvarchar(80)

	Declare @Analyte_Flag as char(5)
	Declare @Method_Flag as char(5)
	Declare @Instrument_Flag as char(5)
	Declare @Reagent_Flag as char(5)
	Declare @Unit_Flag as char(5)
	Declare @Temperature_Flag as char(5)
	Declare @LabLotTestID as int
	Declare @EnteredDate as datetime
	Declare @SlideGen as tinyint
	Declare @TestID as int
	Declare @strSQL as nvarchar(200)
	Declare @mDate as datetime
	Declare @mDateminus24 as datetime
	Declare @RuleSettingsString as nvarchar(100)
	Declare @LabLotTestInfo as nvarchar(200)
	Declare @SequenceID as int
	Declare @ByteLevelsInUsedMask as int
	Declare @TempReagentID as smallint
	Declare @TestCount as int
	Declare @TestCount1 as int
	Declare @Decimal1 as tinyint, @Decimal2 as tinyint, @Decimal3 as tinyint, @Decimal4 as tinyint, @Decimal5 as tinyint,
			@Decimal6 as tinyint, @Decimal7 as tinyint, @Decimal8 as tinyint, @Decimal9 as tinyint  



--	BEGIN TRANSACTION Create_LabLotTest

	
	Select @AnalyteName = Name, @Analyte_Flag = Flag  From Analyte Where AnalyteID = @AnalyteID
	Select @MethodName = Name, @Method_Flag  = Flag From Method Where MethodID = @MethodID
	Select @InstrumentName = Name, @Instrument_Flag = Flag From Instrument Where InstrumentID = @InstrumentID

	if (@ReagentID >= 1000) And (@ReagentID <= 1099)
	Begin
		SET @SlideGen = @ReagentID - 1000 
		SET @TempReagentID = 1000
		Select @ReagentName = Name, @Reagent_Flag = Flag From Reagent Where ReagentID = @TempReagentID
		SET @ReagentName = Replace(@ReagentName,  '00', @SlideGen)

	End
	Else
	Begin
		Select @ReagentName = Name, @Reagent_Flag = Flag From Reagent Where ReagentID = @ReagentID
	End

	Select @UnitName = Name, @Unit_Flag = flag  From Unit Where UnitID = @UnitID
	Select @TemperatureName = Name, @Temperature_Flag = flag From Temperature Where TemperatureID = @TemperatureID

	Select @ExpiredDate = ExpiredDate, @Levels = Levels  from LabLot Where LabID = @LabID and LotID = @LotID
	
	Select @TestCount1 = ISNULL(Count(*), 0)  FROM Test WHERE AnalyteID = @AnalyteID and MethodID = @MethodID and InstrumentID = @InstrumentID and
		ReagentID = @ReagentID and UnitID = @UnitId and TemperatureID = @TemperatureID 

	SET @TestCount1 = ISNULL(@TestCount1, 0)
	If  (@TestCount1 > 0)
	Begin
		Select @TestID = TestID FROM Test WHERE AnalyteID = @AnalyteID and MethodID = @MethodID and InstrumentID = @InstrumentID and
			ReagentID = @ReagentID and UnitID = @UnitId and TemperatureID = @TemperatureID 

		Select @Count = count(*) from LabLotTest Where LabID = @LabID and LotID = @LotID and TestID = @TestID
	End
	Else
		SET @Count = 0

	Set @LabLotTestID = 0
	if (@Count > 0)
	Begin
		-- 2009/07/21   Vu Fixed
		Select @LabLotTestID = LabLotTestID, @lltEnteredDate = EnteredDate  from LabLotTest Where LabID = @LabID and LotID = @LotID and TestID = @TestID and Status = 1
		SET @LabLotTestID = ISNULL(@LabLotTestID, 0)
		if (@LabLotTestID > 0)
			SET @ErrorFlag = 0
		Else
			SET @ErrorFlag = 2
	End
	else
	begin
		if (@CreateTestOption > 0)
		begin
			BEGIN TRANSACTION CreateTest

			Set @TestID = (Select ISNULL(TestID, 0) FROM Test
			WHERE AnalyteID = @AnalyteID and MethodID = @MethodID and InstrumentID = @InstrumentID and
				ReagentID = @ReagentID and UnitID = @UnitId and TemperatureID = @TemperatureID)
			SET @TestID = ISNULL(@TestID, 0)

			if @TestID = 0
			Begin
				Select @TestCount = max(testid) FROM Test
				Set @TestCount = ISNULL(@TestCount, 0)
				if (@TestCount = 0) 
						SET @TestID =  1

				else
						SET @TestID = @TestCount + 1

				Insert INTO Test VALUES (@TestID, @AnalyteID, @InstrumentID, @MethodID, 
					 @ReagentID, @TemperatureID, @UnitID,GetDate(),
					@RuleNames, '2|0|0|0|0|0|0|2|0|0|0|0|0|0|0|0|0|')
				SET @strSQL = 'Add | Test | TestID= ' + str(@TestID)
				INSERT into AuditTransaction VALUES (0, GetDate(), @op, @strSQL)
			End

			COMMIT TRANSACTION CreateTest

			SET @mDate = GetDate()
			SET @mDateminus24 = DateAdd(year,0, @mDate)
			SET @lltEnteredDate = @mDateminus24
				
			Select @RuleSettingsString = RuleSettingsString FROM LabLot
				WHERE LabId = @LabID and LotID = @LotID

			SET @strSQL = 'Mandelic Acid|HPLC|Roche MODULAR ISE|Dedicated Reagent|mg/L|No Temperature'
			SET @LabLotTestInfo = @AnalyteName + '|' +
					 @MethodName + '|' +
					 @InstrumentName + '|' +
					 @ReagentName + '|' +
					 @UnitName + '|' +
					 @TemperatureName 

			if ( @Levels > 3 )
				SET @ByteLevelsInUsedMask = 15
			else
				SET @ByteLevelsInUsedMask = POWER(2, @Levels) - 1

			Select @Decimal1 = Level1Decimal, @Decimal2 = Level2Decimal, @Decimal3 = Level3Decimal,
				@Decimal4 = Level4Decimal, @Decimal5 = Level5Decimal, @Decimal6 = Level6Decimal,
				@Decimal7 = Level7Decimal, @Decimal8 = Level8Decimal, @Decimal9 = Level9Decimal
			FROM LabLot where LabID = @LabID and LotID = @LotID

			--SET TRANSACTION ISOLATION LEVEL SERIALIZABLE	
			--BEGIN TRANSACTION ADD_LABLOTTEST

--				Set  @TestCount = (Select  ISNULL(Count(*), 0)  FROM LabLotTest) 
--				Set @TestCount = ISNULL(@TestCount, 0)
--
--				IF (@TestCount = 0) 
--				Begin
--					SET @LabLotTestID = 1
--					SET @SequenceID =  1
--				End
--				Else
--				Begin
--					Select @LabLotTestID = max(LabLotTestID) + 1 FROM LabLotTest
--					Set @SequenceID = (Select ISNULL(max(SequenceID) + 1, 1)  FROM LabLotTest WHERE LabID = @LabID AND LotID = @LotID)
--					set @SequenceID = ISNULL(@SequenceID, 1) 
--
--				End

				Exec LabLotTest_Add_SP1 @LabLotTestID,  @LabID, @LotID, @TestID , @mDateminus24, @mDate , 0, 0, 20,@ByteLevelsInUsedMask,2,1,
					@RuleNames,
					@RuleSettingsString,
					@Decimal1, @Decimal2, @Decimal3, @Decimal4, @Decimal5,
					@Decimal6, @Decimal7, @Decimal8, @Decimal9, '', @LabLotTestInfo, @Sequenceid, @LanguageID

				Select @LabLotTestID = LabLotTestID from LabLotTest Where LabID = @LabID and LotID = @LotID and TestID = @TestID
			--COMMIT TRANSACTION ADD_LABLOTTEST

			SET @strSQL = 'Add | LabLotTest | LabLotTestID=' + str(@LabLotTestID)
			INSERT AuditTransaction VALUES (0, GetDate(), @op, @strSQL)
			-- Remove the redundant ResTestRep because Exec LabLotTest_Add_SP1 already generates the ResTestRep.  
						
			SET @Count = 1
			SET @ErrorFlag = 0
		end
		else
		Begin
			SET 	@ErrorFlag = 1
			GOTO   GO_EXIT
		End

	
	end


	
GO_EXIT:

		SET @ErrorFlag	 	= 	 ISNULL(@ErrorFlag, 0)
		SET @mLabLotTestID	 	= 	 ISNULL(@LabLotTestID, 0)
		SET @mEnteredDate	 	= 	 ISNULL(@lltEnteredDate, 0)

--	COMMIT TRANSACTION Create_LabLotTest
	RETURN


GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[MonthlySummary_sp]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
   drop procedure [dbo].[MonthlySummary_sp]
GO

create procedure [dbo].[MonthlySummary_sp] (@SelectedYearMonth nvarchar(6), @SelectedLabID int, @SelectedLotID nvarchar(15), @SelectedLabLotTestID int, @SelectedInstrumentID smallint, @SelectedPanelName nvarchar(200))
as
   declare @LabLotTestID int
   declare @YearMonth    nvarchar(6)
   declare @L1Mean   real
   declare @L1SD     real
   declare @L1Points int
   declare @L2Mean   real
   declare @L2SD     real
   declare @L2Points int
   declare @L3Mean   real
   declare @L3SD     real
   declare @L3Points int
   declare @L4Mean   real
   declare @L4SD     real
   declare @L4Points int
   declare @L5Mean   real
   declare @L5SD     real
   declare @L5Points int
   declare @L6Mean   real
   declare @L6SD     real
   declare @L6Points int
   declare @L7Mean   real
   declare @L7SD     real
   declare @L7Points int
   declare @L8Mean   real
   declare @L8SD     real
   declare @L8Points int
   declare @L9Mean   real
   declare @L9SD     real
   declare @L9Points int

   declare @L1CumMean   real
   declare @L1CumSD     real
   declare @L1CumPoints int
   declare @L2CumMean   real
   declare @L2CumSD     real
   declare @L2CumPoints int
   declare @L3CumMean   real
   declare @L3CumSD     real
   declare @L3CumPoints int
   declare @L4CumMean   real
   declare @L4CumSD     real
   declare @L4CumPoints int
   declare @L5CumMean   real
   declare @L5CumSD     real
   declare @L5CumPoints int
   declare @L6CumMean   real
   declare @L6CumSD     real
   declare @L6CumPoints int
   declare @L7CumMean   real
   declare @L7CumSD     real
   declare @L7CumPoints int
   declare @L8CumMean   real
   declare @L8CumSD     real
   declare @L8CumPoints int
   declare @L9CumMean   real
   declare @L9CumSD     real
   declare @L9CumPoints int

   declare @LevelsInUse int

   declare @L1InUse   int
   declare @L2InUse   int
   declare @L3InUse   int
   declare @L4InUse   int
   declare @L5InUse   int
   declare @L6InUse   int
   declare @L7InUse   int
   declare @L8InUse   int
   declare @L9InUse   int

   SET NOCOUNT ON

   select @SelectedLabLotTestID = isnull(@SelectedLabLotTestID,0)

   --Prepare temporary tables
   select * into #MonthlySummary from MonthlySummary where 1=2
   select * into #MonthlySummary_Work from MonthlySummary where 1=2

   --Check for levels used across selection
   select @LevelsInUse = MAX(LevelsInUseMask & 1)  + MAX(LevelsInUseMask & 2)   + MAX(LevelsInUseMask & 4)   + 
                         MAX(LevelsInUseMask & 8)  + MAX(LevelsInUseMask & 16)  + MAX(LevelsInUseMask & 32)  +
                         MAX(LevelsInUseMask & 64) + MAX(LevelsInUseMask & 128) + MAX(LevelsInUseMask & 256)
   from LabLotTest (NOLOCK)
   where LabLotTestID = @SelectedLabLotTestID

   select @L1InUse = CASE WHEN (@LevelsInUse & 1)  > 0 THEN 1 ELSE 0 END, @L2InUse = CASE WHEN (@LevelsInUse & 2)   > 0 THEN 1 ELSE 0 END, @L3InUse = CASE WHEN (@LevelsInUse & 4)   > 0 THEN 1 ELSE 0 END, 
          @L4InUse = CASE WHEN (@LevelsInUse & 8)  > 0 THEN 1 ELSE 0 END, @L5InUse = CASE WHEN (@LevelsInUse & 16)  > 0 THEN 1 ELSE 0 END, @L6InUse = CASE WHEN (@LevelsInUse & 32)  > 0 THEN 1 ELSE 0 END, 
          @L7InUse = CASE WHEN (@LevelsInUse & 64) > 0 THEN 1 ELSE 0 END, @L8InUse = CASE WHEN (@LevelsInUse & 128) > 0 THEN 1 ELSE 0 END, @L9InUse = CASE WHEN (@LevelsInUse & 256) > 0 THEN 1 ELSE 0 END 

   --Recalculate Monthly Summary data from PointData and populate temporary table
   IF (ISNULL(@L1InUse,0) = 1)
   BEGIN
      insert #MonthlySummary_Work
      select LabLotTestID, convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2) YearMonth,
             ISNULL(avg(level1value),0) L1Mean, ISNULL(stdev(level1value),0) L1SD, sum(1) L1Points,
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
      from pointdata (NOLOCK)
      where level1status = 1 and not level1value is NULL
      and   ((@SelectedYearMonth = '')   or (@SelectedYearMonth <> ''  and convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2) = @SelectedYearMonth))
      and   LabLotTestID = @SelectedLabLotTestID
      group by LabLotTestID, convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2)
      order by LabLotTestID, convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2)
   END


   IF (ISNULL(@L2InUse,0) = 1)
   BEGIN
      insert #MonthlySummary_Work
      select LabLotTestID, convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2) YearMonth,
             0,0,0,
             ISNULL(avg(level2value),0) L2Mean, ISNULL(stdev(level2value),0) L2SD, sum(1) L2Points,
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
      from pointdata (NOLOCK)
      where level2status = 1 and not level2value is NULL
      and   ((@SelectedYearMonth = '')   or (@SelectedYearMonth <> ''  and convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2) = @SelectedYearMonth))
      and   LabLotTestID = @SelectedLabLotTestID
      group by LabLotTestID, convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2)
      order by LabLotTestID, convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2)
   END


   IF (ISNULL(@L3InUse,0) = 1)
   BEGIN
      insert #MonthlySummary_Work
      select LabLotTestID, convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2) YearMonth,
             0,0,0,0,0,0,
             ISNULL(avg(level3value),0) L3Mean, ISNULL(stdev(level3value),0) L3SD, sum(1) L3Points,
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
      from pointdata (NOLOCK)
      where level3status = 1 and not level3value is NULL
      and   ((@SelectedYearMonth = '')   or (@SelectedYearMonth <> ''  and convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2) = @SelectedYearMonth))
      and   LabLotTestID = @SelectedLabLotTestID
       group by LabLotTestID, convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2)
      order by LabLotTestID, convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2)
   END


   IF (ISNULL(@L4InUse,0) = 1)
   BEGIN
      insert #MonthlySummary_Work
      select LabLotTestID, convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2) YearMonth,
             0,0,0,0,0,0,0,0,0,
             ISNULL(avg(level4value),0) L4Mean, ISNULL(stdev(level4value),0) L4SD, sum(1) L4Points,
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
      from pointdata (NOLOCK)
      where level4status = 1 and not level4value is NULL
      and   ((@SelectedYearMonth = '')   or (@SelectedYearMonth <> ''  and convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2) = @SelectedYearMonth))
      and   LabLotTestID = @SelectedLabLotTestID
      group by LabLotTestID, convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2)
      order by LabLotTestID, convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2)
   END


   IF (ISNULL(@L5InUse,0) = 1)
   BEGIN
      insert #MonthlySummary_Work
      select LabLotTestID, convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2) YearMonth,
             0,0,0,0,0,0,0,0,0,0,0,0,
             ISNULL(avg(level5value),0) L5Mean, ISNULL(stdev(level5value),0) L5SD, sum(1) L5Points,
             0,0,0,0,0,0,0,0,0,0,0,0
      from pointdata (NOLOCK)
      where level5status = 1 and not level5value is NULL
      and   ((@SelectedYearMonth = '')   or (@SelectedYearMonth <> ''  and convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2) = @SelectedYearMonth))
      and   LabLotTestID = @SelectedLabLotTestID
      group by LabLotTestID, convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2)
      order by LabLotTestID, convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2)
   END


   IF (ISNULL(@L6InUse,0) = 1)
   BEGIN
      insert #MonthlySummary_Work
      select LabLotTestID, convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2) YearMonth,
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
             ISNULL(avg(level6value),0) L6Mean, ISNULL(stdev(level6value),0) L6SD, sum(1) L6Points,
             0,0,0,0,0,0,0,0,0
      from pointdata (NOLOCK)
      where level6status = 1 and not level6value is NULL
      and   ((@SelectedYearMonth = '')   or (@SelectedYearMonth <> ''  and convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2) = @SelectedYearMonth))
      and   LabLotTestID = @SelectedLabLotTestID
      group by LabLotTestID, convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2)
      order by LabLotTestID, convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2)
   END


   IF (ISNULL(@L7InUse,0) = 1)
   BEGIN
      insert #MonthlySummary_Work
      select LabLotTestID, convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2) YearMonth,
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
             ISNULL(avg(level7value),0) L7Mean, ISNULL(stdev(level7value),0) L7SD, sum(1) L7Points,
             0,0,0,0,0,0
      from pointdata (NOLOCK)
      where level7status = 1 and not level7value is NULL
      and   ((@SelectedYearMonth = '')   or (@SelectedYearMonth <> ''  and convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2) = @SelectedYearMonth))
      and   LabLotTestID = @SelectedLabLotTestID
      group by LabLotTestID, convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2)
      order by LabLotTestID, convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2)
   END


   IF (ISNULL(@L8InUse,0) = 1)
   BEGIN
      insert #MonthlySummary_Work
      select LabLotTestID, convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2) YearMonth,
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
             ISNULL(avg(level8value),0) L8Mean, ISNULL(stdev(level8value),0) L8SD, sum(1) L8Points,
             0,0,0
      from pointdata (NOLOCK)
      where level8status = 1 and not level8value is NULL
      and   ((@SelectedYearMonth = '')   or (@SelectedYearMonth <> ''  and convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2) = @SelectedYearMonth))
      and   LabLotTestID = @SelectedLabLotTestID
      group by LabLotTestID, convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2)
      order by LabLotTestID, convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2)
   END


   IF (ISNULL(@L9InUse,0) = 1)
   BEGIN
      insert #MonthlySummary_Work
      select LabLotTestID, convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2) YearMonth,
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
             ISNULL(avg(level9value),0) L9Mean, ISNULL(stdev(level9value),0) L9SD, sum(1) L9Points
      from pointdata (NOLOCK)
      where level9status = 1 and not level9value is NULL
      and   ((@SelectedYearMonth = '')   or (@SelectedYearMonth <> ''  and convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2) = @SelectedYearMonth))
      and   LabLotTestID = @SelectedLabLotTestID
      group by LabLotTestID, convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2)
      order by LabLotTestID, convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2)
   END


   insert #MonthlySummary
   select LabLotTestID, YearMonth, 
          sum(L1Mean), max(L1SD), max(L1Points), sum(L2Mean), max(L2SD), max(L2Points), sum(L3Mean), max(L3SD), max(L3Points),
          sum(L4Mean), max(L4SD), max(L4Points), sum(L5Mean), max(L5SD), max(L5Points), sum(L6Mean), max(L6SD), max(L6Points),
          sum(L7Mean), max(L7SD), max(L7Points), sum(L8Mean), max(L8SD), max(L8Points), sum(L9Mean), max(L9SD), max(L9Points)
   from #MonthlySummary_Work
   group by LabLotTestID, YearMonth
   order by LabLotTestID, YearMonth


   --When processing Summary Data, it is possible that no Point Data for the matching month existed and therefore
   --no row had been added above in temporary table for lablottest/yearmonth combination.  In order to avoid the need
   --to have duplicate queries to handle adding new row for Summary Data in temporary table or to update existing row
   --in temporary table, insert empty rows into temporary table based on expected rows from Summary Data that are not
   --already in temporary table.
   insert #MonthlySummary 
   select LabLotTestID, (convert(varchar(4),datepart(yy,sd.entereddate)) + right('0' + convert(varchar(2),datepart(mm,sd.entereddate)),2)),
                                  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
   from SummaryData sd (NOLOCK)
   where not exists(select 1 
                    from #MonthlySummary ms2 
                    where ms2.LabLotTestID = sd.LabLotTestID 
                      and ms2.YearMonth = (convert(varchar(4),datepart(yy,sd.entereddate)) + right('0' + convert(varchar(2),datepart(mm,sd.entereddate)),2))
                    )
   and ((@SelectedYearMonth = '')   or (@SelectedYearMonth <> ''  and convert(varchar(4),datepart(yy,entereddate)) + right('0' + convert(varchar(2),datepart(mm,entereddate)),2) = @SelectedYearMonth))
   and LabLotTestID = @SelectedLabLotTestID

   --Define SQL query for retrieving Summary Data.  Using Cursor as each row has to be processed individually to 
   --combine summary mean, sd and points to existing data.
   DECLARE SummaryData_Cursor CURSOR FOR
   SELECT sd.LabLotTestID, (convert(varchar(4),datepart(yy,sd.entereddate)) + right('0' + convert(varchar(2),datepart(mm,sd.entereddate)),2)) YearMonth,
          sd.Level1Mean, sd.Level1SD, sd.Level1Points, sd.Level2Mean, sd.Level2SD, sd.Level2Points,           
          sd.Level3Mean, sd.Level3SD, sd.Level3Points, sd.Level4Mean, sd.Level4SD, sd.Level4Points,           
          sd.Level5Mean, sd.Level5SD, sd.Level5Points, sd.Level6Mean, sd.Level6SD, sd.Level6Points,           
          sd.Level7Mean, sd.Level7SD, sd.Level7Points, sd.Level8Mean, sd.Level8SD, sd.Level8Points,           
          sd.Level9Mean, sd.Level9SD, sd.Level9Points           
   FROM SummaryData sd (NOLOCK)
   WHERE ((@SelectedYearMonth = '')   or (@SelectedYearMonth <> ''  and convert(varchar(4),datepart(yy,sd.entereddate)) + right('0' + convert(varchar(2),datepart(mm,sd.entereddate)),2) = @SelectedYearMonth))
   and   LabLotTestID = @SelectedLabLotTestID
   ORDER BY sd.LabLotTestID, (convert(varchar(4),datepart(yy,sd.entereddate)) + right('0' + convert(varchar(2),datepart(mm,sd.entereddate)),2))

   OPEN SummaryData_Cursor

   FETCH NEXT FROM SummaryData_Cursor 
   INTO @LabLotTestID, @YearMonth, 
        @L1Mean, @L1SD, @L1Points, @L2Mean, @L2SD, @L2Points, 
        @L3Mean, @L3SD, @L3Points, @L4Mean, @L4SD, @L4Points, 
        @L5Mean, @L5SD, @L5Points, @L6Mean, @L6SD, @L6Points, 
        @L7Mean, @L7SD, @L7Points, @L8Mean, @L8SD, @L8Points, 
        @L9Mean, @L9SD, @L9Points

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SELECT @L1CumMean = tms.L1Mean, @L1CumSD = tms.L1SD, @L1CumPoints = tms.L1Points, 
             @L2CumMean = tms.L2Mean, @L2CumSD = tms.L2SD, @L2CumPoints = tms.L2Points, 
             @L3CumMean = tms.L3Mean, @L3CumSD = tms.L3SD, @L3CumPoints = tms.L3Points, 
             @L4CumMean = tms.L4Mean, @L4CumSD = tms.L4SD, @L4CumPoints = tms.L4Points, 
             @L5CumMean = tms.L5Mean, @L5CumSD = tms.L5SD, @L5CumPoints = tms.L5Points, 
             @L6CumMean = tms.L6Mean, @L6CumSD = tms.L6SD, @L6CumPoints = tms.L6Points, 
             @L7CumMean = tms.L7Mean, @L7CumSD = tms.L7SD, @L7CumPoints = tms.L7Points, 
             @L8CumMean = tms.L8Mean, @L8CumSD = tms.L8SD, @L8CumPoints = tms.L8Points, 
             @L9CumMean = tms.L9Mean, @L9CumSD = tms.L9SD, @L9CumPoints = tms.L9Points      
      FROM #MonthlySummary tms
      WHERE tms.LabLotTestID = @LabLotTestID and tms.YearMonth = @YearMonth

      --Process each set of points for each level by calling usp_CalculateMeanSD to combine to cumulative totals
      IF @L1Points > 0
         EXEC usp_CalculateMeanSD @L1Mean, @L1SD, @L1Points, @L1CumMean OUT, @L1CumSD OUT, @L1CumPoints OUT

      IF @L2Points > 0
         EXEC usp_CalculateMeanSD @L2Mean, @L2SD, @L2Points, @L2CumMean OUT, @L2CumSD OUT, @L2CumPoints OUT

      IF @L3Points > 0
         EXEC usp_CalculateMeanSD @L3Mean, @L3SD, @L3Points, @L3CumMean OUT, @L3CumSD OUT, @L3CumPoints OUT

      IF @L4Points > 0
         EXEC usp_CalculateMeanSD @L4Mean, @L4SD, @L4Points, @L4CumMean OUT, @L4CumSD OUT, @L4CumPoints OUT

      IF @L5Points > 0
         EXEC usp_CalculateMeanSD @L5Mean, @L5SD, @L5Points, @L5CumMean OUT, @L5CumSD OUT, @L5CumPoints OUT

      IF @L6Points > 0
         EXEC usp_CalculateMeanSD @L6Mean, @L6SD, @L6Points, @L6CumMean OUT, @L6CumSD OUT, @L6CumPoints OUT

      IF @L7Points > 0
         EXEC usp_CalculateMeanSD @L7Mean, @L7SD, @L7Points, @L7CumMean OUT, @L7CumSD OUT, @L7CumPoints OUT

      IF @L8Points > 0
         EXEC usp_CalculateMeanSD @L8Mean, @L8SD, @L8Points, @L8CumMean OUT, @L8CumSD OUT, @L8CumPoints OUT

      IF @L9Points > 0
         EXEC usp_CalculateMeanSD @L9Mean, @L9SD, @L9Points, @L9CumMean OUT, @L9CumSD OUT, @L9CumPoints OUT

      UPDATE #MonthlySummary
      SET L1Mean = @L1CumMean, L1SD = @L1CumSD, L1Points = @L1CumPoints, 
          L2Mean = @L2CumMean, L2SD = @L2CumSD, L2Points = @L2CumPoints, 
          L3Mean = @L3CumMean, L3SD = @L3CumSD, L3Points = @L3CumPoints, 
          L4Mean = @L4CumMean, L4SD = @L4CumSD, L4Points = @L4CumPoints, 
          L5Mean = @L5CumMean, L5SD = @L5CumSD, L5Points = @L5CumPoints, 
          L6Mean = @L6CumMean, L6SD = @L6CumSD, L6Points = @L6CumPoints, 
          L7Mean = @L7CumMean, L7SD = @L7CumSD, L7Points = @L7CumPoints, 
          L8Mean = @L8CumMean, L8SD = @L8CumSD, L8Points = @L8CumPoints, 
          L9Mean = @L9CumMean, L9SD = @L9CumSD, L9Points = @L9CumPoints
      WHERE LabLotTestID = @LabLotTestID and YearMonth = @YearMonth


      FETCH NEXT FROM SummaryData_Cursor
      INTO @LabLotTestID, @YearMonth, 
           @L1Mean, @L1SD, @L1Points, @L2Mean, @L2SD, @L2Points, 
           @L3Mean, @L3SD, @L3Points, @L4Mean, @L4SD, @L4Points, 
           @L5Mean, @L5SD, @L5Points, @L6Mean, @L6SD, @L6Points, 
           @L7Mean, @L7SD, @L7Points, @L8Mean, @L8SD, @L8Points, 
           @L9Mean, @L9SD, @L9Points

   END

   CLOSE SummaryData_Cursor
   DEALLOCATE SummaryData_Cursor

   
   --In order to avoid needing to handle Insert and Update to Monthly Summary depending on if there was an existing
   --row, create Monthly Summary row with empty values based on temporary table where there is no existing row 
   --matching the lablottestid/yearmonth
   insert MonthlySummary 
   select LabLotTestID, tms.YearMonth,
          0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
   from #MonthlySummary tms
   where not exists(select 1 
                    from MonthlySummary ms2 
                    where ms2.LabLotTestID = tms.LabLotTestID 
                      and ms2.YearMonth = tms.YearMonth
                    )
   

   --Update MonthSummary table with calculated values
   UPDATE MonthlySummary
   SET MonthlySummary.L1Mean = tms.L1Mean, MonthlySummary.L1SD = tms.L1SD, MonthlySummary.L1Points = tms.L1Points, 
       MonthlySummary.L2Mean = tms.L2Mean, MonthlySummary.L2SD = tms.L2SD, MonthlySummary.L2Points = tms.L2Points, 
       MonthlySummary.L3Mean = tms.L3Mean, MonthlySummary.L3SD = tms.L3SD, MonthlySummary.L3Points = tms.L3Points, 
       MonthlySummary.L4Mean = tms.L4Mean, MonthlySummary.L4SD = tms.L4SD, MonthlySummary.L4Points = tms.L4Points, 
       MonthlySummary.L5Mean = tms.L5Mean, MonthlySummary.L5SD = tms.L5SD, MonthlySummary.L5Points = tms.L5Points, 
       MonthlySummary.L6Mean = tms.L6Mean, MonthlySummary.L6SD = tms.L6SD, MonthlySummary.L6Points = tms.L6Points, 
       MonthlySummary.L7Mean = tms.L7Mean, MonthlySummary.L7SD = tms.L7SD, MonthlySummary.L7Points = tms.L7Points, 
       MonthlySummary.L8Mean = tms.L8Mean, MonthlySummary.L8SD = tms.L8SD, MonthlySummary.L8Points = tms.L8Points, 
       MonthlySummary.L9Mean = tms.L9Mean, MonthlySummary.L9SD = tms.L9SD, MonthlySummary.L9Points = tms.L9Points
   FROM #MonthlySummary tms
   WHERE MonthlySummary.LabLotTestID = tms.LabLotTestID and MonthlySummary.YearMonth = tms.YearMonth


   --Clean existing Monthly Summary row if there is no row in temporary table for lablottestid/yearmonth and therefore
   --no balance available.
   UPDATE MonthlySummary
   SET MonthlySummary.L1Mean = 0, MonthlySummary.L1SD = 0, MonthlySummary.L1Points = 0, 
       MonthlySummary.L2Mean = 0, MonthlySummary.L2SD = 0, MonthlySummary.L2Points = 0, 
       MonthlySummary.L3Mean = 0, MonthlySummary.L3SD = 0, MonthlySummary.L3Points = 0, 
       MonthlySummary.L4Mean = 0, MonthlySummary.L4SD = 0, MonthlySummary.L4Points = 0, 
       MonthlySummary.L5Mean = 0, MonthlySummary.L5SD = 0, MonthlySummary.L5Points = 0, 
       MonthlySummary.L6Mean = 0, MonthlySummary.L6SD = 0, MonthlySummary.L6Points = 0, 
       MonthlySummary.L7Mean = 0, MonthlySummary.L7SD = 0, MonthlySummary.L7Points = 0, 
       MonthlySummary.L8Mean = 0, MonthlySummary.L8SD = 0, MonthlySummary.L8Points = 0, 
       MonthlySummary.L9Mean = 0, MonthlySummary.L9SD = 0, MonthlySummary.L9Points = 0
   WHERE ((@SelectedYearMonth = '')   or (@SelectedYearMonth <> ''  and YearMonth = @SelectedYearMonth))
   and   LabLotTestID = @SelectedLabLotTestID
   and NOT EXISTS (SELECT 1 
                  FROM #MonthlySummary 
                  WHERE MonthlySummary.LabLotTestID = #MonthlySummary.LabLotTestID
                  AND   MonthlySummary.YearMonth    = #MonthlySummary.YearMonth
                  )

GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[StartDate_FloatMeanSD_sp]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
   drop procedure [dbo].[StartDate_FloatMeanSD_sp]
GO

create procedure [dbo].[StartDate_FloatMeanSD_sp] (@SelectedLabID int, @SelectedLotID nvarchar(15), @SelectedLabLotTestID int, @SelectedInstrumentID smallint, @SelectedPanelName nvarchar(200))
as
   declare @LabLotTestID int
   declare @StartDate    datetime
   declare @L1Mean   real
   declare @L1SD     real
   declare @L1Points int
   declare @L2Mean   real
   declare @L2SD     real
   declare @L2Points int
   declare @L3Mean   real
   declare @L3SD     real
   declare @L3Points int
   declare @L4Mean   real
   declare @L4SD     real
   declare @L4Points int
   declare @L5Mean   real
   declare @L5SD     real
   declare @L5Points int
   declare @L6Mean   real
   declare @L6SD     real
   declare @L6Points int
   declare @L7Mean   real
   declare @L7SD     real
   declare @L7Points int
   declare @L8Mean   real
   declare @L8SD     real
   declare @L8Points int
   declare @L9Mean   real
   declare @L9SD     real
   declare @L9Points int

   declare @L1CumMean   real
   declare @L1CumSD     real
   declare @L1CumPoints int
   declare @L2CumMean   real
   declare @L2CumSD     real
   declare @L2CumPoints int
   declare @L3CumMean   real
   declare @L3CumSD     real
   declare @L3CumPoints int
   declare @L4CumMean   real
   declare @L4CumSD     real
   declare @L4CumPoints int
   declare @L5CumMean   real
   declare @L5CumSD     real
   declare @L5CumPoints int
   declare @L6CumMean   real
   declare @L6CumSD     real
   declare @L6CumPoints int
   declare @L7CumMean   real
   declare @L7CumSD     real
   declare @L7CumPoints int
   declare @L8CumMean   real
   declare @L8CumSD     real
   declare @L8CumPoints int
   declare @L9CumMean   real
   declare @L9CumSD     real
   declare @L9CumPoints int

   declare @LevelsInUse int
   
   declare @L1InUse   int
   declare @L2InUse   int
   declare @L3InUse   int
   declare @L4InUse   int
   declare @L5InUse   int
   declare @L6InUse   int
   declare @L7InUse   int
   declare @L8InUse   int
   declare @L9InUse   int

   SET NOCOUNT ON

   select @SelectedLabLotTestID = isnull(@SelectedLabLotTestID,0)

   --Prepare temporary tables
   select * into #StartDate_FloatMeanSD from StartDate_FloatMeanSD where 1=2
   select * into #StartDate_FloatMeanSD_Work from StartDate_FloatMeanSD where 1=2


   --Insert any missing StartDate_FloatMeanSD rows that were part of selection.  Creation of new tests should auto-create 
   --StartDate_FloatMeanSD rows, but older tests may not as yet have the row.
   insert StartDate_FloatMeanSD 
   select LabLotTestID, '1980-01-01',
          0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
   from LabLotTest llt (NOLOCK)
   WHERE LabLotTestID = @SelectedLabLotTestID
   and not exists(select 1 
                  from StartDate_FloatMeanSD flms2 
                  where flms2.LabLotTestID = llt.LabLotTestID 
                 )


   --Check for levels used across selection
   select @LevelsInUse = MAX(LevelsInUseMask & 1)  + MAX(LevelsInUseMask & 2)   + MAX(LevelsInUseMask & 4)   + 
                         MAX(LevelsInUseMask & 8)  + MAX(LevelsInUseMask & 16)  + MAX(LevelsInUseMask & 32)  +
                         MAX(LevelsInUseMask & 64) + MAX(LevelsInUseMask & 128) + MAX(LevelsInUseMask & 256)
   from LabLotTest (NOLOCK)
   where LabLotTestID = @SelectedLabLotTestID
   
/*
   select @L1InUse = MAX(CASE WHEN (level1status = 1 and level1value <> 0) THEN 1 ELSE 0 END),
          @L2InUse = MAX(CASE WHEN (level2status = 1 and level2value <> 0) THEN 1 ELSE 0 END),
          @L3InUse = MAX(CASE WHEN (level3status = 1 and level3value <> 0) THEN 1 ELSE 0 END),
          @L4InUse = MAX(CASE WHEN (level4status = 1 and level4value <> 0) THEN 1 ELSE 0 END),
          @L5InUse = MAX(CASE WHEN (level5status = 1 and level5value <> 0) THEN 1 ELSE 0 END),
          @L6InUse = MAX(CASE WHEN (level6status = 1 and level6value <> 0) THEN 1 ELSE 0 END),
          @L7InUse = MAX(CASE WHEN (level7status = 1 and level7value <> 0) THEN 1 ELSE 0 END),
          @L8InUse = MAX(CASE WHEN (level8status = 1 and level8value <> 0) THEN 1 ELSE 0 END),
          @L9InUse = MAX(CASE WHEN (level9status = 1 and level9value <> 0) THEN 1 ELSE 0 END)
   from pointdata
   where (exists (select 1 from StartDate_FloatMeanSD where pointdata.lablottestid = StartDate_FloatMeanSD.lablottestid and pointdata.entereddate >= StartDate_FloatMeanSD.StartDateTime))
   and   ((@SelectedLabID = 0)        or (@SelectedLabID > 0        and exists (select 1 from lablottest       where lablottest.lablottestid = pointdata.lablottestid and lablottest.labid = @SelectedLabID)))
   and   ((@SelectedLotID = '')       or (@SelectedLotID <> ''      and exists (select 1 from lablottest       where lablottest.lablottestid = pointdata.lablottestid and lablottest.lotid = @SelectedLotID)))
   and   ((@SelectedLabLotTestID = 0) or (@SelectedLabLotTestID > 0 and LabLotTestID = @SelectedLabLotTestID))
   and   ((@SelectedInstrumentID = 0) or (@SelectedInstrumentID > 0 and exists (select 1 from lablottest, test where lablottest.lablottestid = pointdata.lablottestid and lablottest.testid = test.testid and test.instrumentid = @SelectedInstrumentID)))
   and   ((@SelectedPanelName = '')   or (@SelectedPanelName <> ''  and exists (select 1 from panel            where panel.lablottestid      = pointdata.lablottestid and panel.panel_name  = @SelectedPanelName)))
*/

   select @L1InUse = CASE WHEN (@LevelsInUse & 1)  > 0 THEN 1 ELSE 0 END, @L2InUse = CASE WHEN (@LevelsInUse & 2)   > 0 THEN 1 ELSE 0 END, @L3InUse = CASE WHEN (@LevelsInUse & 4)   > 0 THEN 1 ELSE 0 END, 
          @L4InUse = CASE WHEN (@LevelsInUse & 8)  > 0 THEN 1 ELSE 0 END, @L5InUse = CASE WHEN (@LevelsInUse & 16)  > 0 THEN 1 ELSE 0 END, @L6InUse = CASE WHEN (@LevelsInUse & 32)  > 0 THEN 1 ELSE 0 END, 
          @L7InUse = CASE WHEN (@LevelsInUse & 64) > 0 THEN 1 ELSE 0 END, @L8InUse = CASE WHEN (@LevelsInUse & 128) > 0 THEN 1 ELSE 0 END, @L9InUse = CASE WHEN (@LevelsInUse & 256) > 0 THEN 1 ELSE 0 END 

   --Recalculate StartDate_FloatMeanSD data from PointData and populate temporary table
   IF (ISNULL(@L1InUse,0) = 1)
   BEGIN
      insert #StartDate_FloatMeanSD_Work
      select LabLotTestID, '',
             ISNULL(avg(level1value),0) L1Mean, ISNULL(stdev(level1value),0) L1SD, sum(1) L1Points,
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
      from pointdata (NOLOCK)
      where level1status = 1 and not level1value is NULL
      and   (exists (select 1 from StartDate_FloatMeanSD where pointdata.lablottestid = StartDate_FloatMeanSD.lablottestid and pointdata.entereddate >= StartDate_FloatMeanSD.StartDateTime))
      and   LabLotTestID = @SelectedLabLotTestID
      group by LabLotTestID
   END


   IF (ISNULL(@L2InUse,0) = 1)
   BEGIN
      insert #StartDate_FloatMeanSD_Work
      select LabLotTestID, '',
             0,0,0,
             ISNULL(avg(level2value),0) L2Mean, ISNULL(stdev(level2value),0) L2SD, sum(1) L2Points,
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
      from pointdata (NOLOCK)
      where level2status = 1 and not level2value is NULL
      and   (exists (select 1 from StartDate_FloatMeanSD where pointdata.lablottestid = StartDate_FloatMeanSD.lablottestid and pointdata.entereddate >= StartDate_FloatMeanSD.StartDateTime))
      and   LabLotTestID = @SelectedLabLotTestID
      group by LabLotTestID
   END


   IF (ISNULL(@L3InUse,0) = 1)
   BEGIN
      insert #StartDate_FloatMeanSD_Work
      select LabLotTestID, '',
             0,0,0,0,0,0,
             ISNULL(avg(level3value),0) L3Mean, ISNULL(stdev(level3value),0) L3SD, sum(1) L3Points,
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
      from pointdata (NOLOCK)
      where level3status = 1 and not level3value is NULL
      and   (exists (select 1 from StartDate_FloatMeanSD where pointdata.lablottestid = StartDate_FloatMeanSD.lablottestid and pointdata.entereddate >= StartDate_FloatMeanSD.StartDateTime))
      and   LabLotTestID = @SelectedLabLotTestID
      group by LabLotTestID
   END


   IF (ISNULL(@L4InUse,0) = 1)
   BEGIN
      insert #StartDate_FloatMeanSD_Work
      select LabLotTestID, '',
             0,0,0,0,0,0,0,0,0,
             ISNULL(avg(level4value),0) L4Mean, ISNULL(stdev(level4value),0) L4SD, sum(1) L4Points,
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
      from pointdata (NOLOCK)
      where level4status = 1 and not level4value is NULL
      and   (exists (select 1 from StartDate_FloatMeanSD where pointdata.lablottestid = StartDate_FloatMeanSD.lablottestid and pointdata.entereddate >= StartDate_FloatMeanSD.StartDateTime))
      and   LabLotTestID = @SelectedLabLotTestID
      group by LabLotTestID
   END


   IF (ISNULL(@L5InUse,0) = 1)
   BEGIN
      insert #StartDate_FloatMeanSD_Work
      select LabLotTestID, '',
             0,0,0,0,0,0,0,0,0,0,0,0,
             ISNULL(avg(level5value),0) L5Mean, ISNULL(stdev(level5value),0) L5SD, sum(1) L5Points,
             0,0,0,0,0,0,0,0,0,0,0,0
      from pointdata (NOLOCK)
      where level5status = 1 and not level5value is NULL
      and   (exists (select 1 from StartDate_FloatMeanSD where pointdata.lablottestid = StartDate_FloatMeanSD.lablottestid and pointdata.entereddate >= StartDate_FloatMeanSD.StartDateTime))
      and   LabLotTestID = @SelectedLabLotTestID
      group by LabLotTestID
   END


   IF (ISNULL(@L6InUse,0) = 1)
   BEGIN
      insert #StartDate_FloatMeanSD_Work
      select LabLotTestID, '',
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
             ISNULL(avg(level6value),0) L6Mean, ISNULL(stdev(level6value),0) L6SD, sum(1) L6Points,
             0,0,0,0,0,0,0,0,0
      from pointdata (NOLOCK)
      where level6status = 1 and not level6value is NULL
      and   (exists (select 1 from StartDate_FloatMeanSD where pointdata.lablottestid = StartDate_FloatMeanSD.lablottestid and pointdata.entereddate >= StartDate_FloatMeanSD.StartDateTime))
      and   LabLotTestID = @SelectedLabLotTestID
      group by LabLotTestID
   END


   IF (ISNULL(@L7InUse,0) = 1)
   BEGIN
      insert #StartDate_FloatMeanSD_Work
      select LabLotTestID, '',
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
             ISNULL(avg(level7value),0) L7Mean, ISNULL(stdev(level7value),0) L7SD, sum(1) L7Points,
             0,0,0,0,0,0
      from pointdata (NOLOCK)
      where level7status = 1 and not level7value is NULL
      and   (exists (select 1 from StartDate_FloatMeanSD where pointdata.lablottestid = StartDate_FloatMeanSD.lablottestid and pointdata.entereddate >= StartDate_FloatMeanSD.StartDateTime))
      and   LabLotTestID = @SelectedLabLotTestID
      group by LabLotTestID
   END


   IF (ISNULL(@L8InUse,0) = 1)
   BEGIN
      insert #StartDate_FloatMeanSD_Work
      select LabLotTestID, '',
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
             ISNULL(avg(level8value),0) L8Mean, ISNULL(stdev(level8value),0) L8SD, sum(1) L8Points,
             0,0,0
      from pointdata (NOLOCK)
      where level8status = 1 and not level8value is NULL
      and   (exists (select 1 from StartDate_FloatMeanSD where pointdata.lablottestid = StartDate_FloatMeanSD.lablottestid and pointdata.entereddate >= StartDate_FloatMeanSD.StartDateTime))
      and   LabLotTestID = @SelectedLabLotTestID
      group by LabLotTestID
   END


   IF (ISNULL(@L9InUse,0) = 1)
   BEGIN
      insert #StartDate_FloatMeanSD_Work
      select LabLotTestID, '',
             0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
             ISNULL(avg(level9value),0) L9Mean, ISNULL(stdev(level9value),0) L9SD, sum(1) L9Points
      from pointdata (NOLOCK)
      where level9status = 1 and not level9value is NULL
      and   (exists (select 1 from StartDate_FloatMeanSD where pointdata.lablottestid = StartDate_FloatMeanSD.lablottestid and pointdata.entereddate >= StartDate_FloatMeanSD.StartDateTime))
      and   LabLotTestID = @SelectedLabLotTestID
      group by LabLotTestID
   END


   insert #StartDate_FloatMeanSD
   select LabLotTestID, StartDateTime, 
          sum(Level1FloatMean), max(Level1FloatSD), max(Level1FloatPoints), sum(Level2FloatMean), max(Level2FloatSD), max(Level2FloatPoints), sum(Level3FloatMean), max(Level3FloatSD), max(Level3FloatPoints),
          sum(Level4FloatMean), max(Level4FloatSD), max(Level4FloatPoints), sum(Level5FloatMean), max(Level5FloatSD), max(Level5FloatPoints), sum(Level6FloatMean), max(Level6FloatSD), max(Level6FloatPoints),
          sum(Level7FloatMean), max(Level7FloatSD), max(Level7FloatPoints), sum(Level8FloatMean), max(Level8FloatSD), max(Level8FloatPoints), sum(Level9FloatMean), max(Level9FloatSD), max(Level9FloatPoints)
   from #StartDate_FloatMeanSD_Work
   group by LabLotTestID, StartDateTime
   order by LabLotTestID, StartDateTime


   --When processing Summary Data, it is possible that no Point Data for the matching month existed and therefore
   --no row had been added above in temporary table for lablottest/yearmonth combination.  In order to avoid the need
   --to have duplicate queries to handle adding new row for Summary Data in temporary table or to update existing row
   --in temporary table, insert empty rows into temporary table based on expected rows from Summary Data that are not
   --already in temporary table.
   insert #StartDate_FloatMeanSD 
   select LabLotTestID, '',
                                  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
   from SummaryData sd (NOLOCK)
   where not exists(select 1 
                    from #StartDate_FloatMeanSD sdfm2 
                    where sdfm2.LabLotTestID = sd.LabLotTestID 
                   )
   and (exists (select 1 from StartDate_FloatMeanSD where sd.lablottestid = StartDate_FloatMeanSD.lablottestid and sd.entereddate >= StartDate_FloatMeanSD.StartDateTime))
   and LabLotTestID = @SelectedLabLotTestID

   --Define SQL query for retrieving Summary Data.  Using Cursor as each row has to be processed individually to 
   --combine summary mean, sd and points to existing data.
   DECLARE SummaryData_Cursor CURSOR FOR
   SELECT sd.LabLotTestID, 
          sd.Level1Mean, sd.Level1SD, sd.Level1Points, sd.Level2Mean, sd.Level2SD, sd.Level2Points,           
          sd.Level3Mean, sd.Level3SD, sd.Level3Points, sd.Level4Mean, sd.Level4SD, sd.Level4Points,           
          sd.Level5Mean, sd.Level5SD, sd.Level5Points, sd.Level6Mean, sd.Level6SD, sd.Level6Points,           
          sd.Level7Mean, sd.Level7SD, sd.Level7Points, sd.Level8Mean, sd.Level8SD, sd.Level8Points,           
          sd.Level9Mean, sd.Level9SD, sd.Level9Points           
   FROM SummaryData sd (NOLOCK)
   WHERE (exists (select 1 from StartDate_FloatMeanSD where sd.lablottestid = StartDate_FloatMeanSD.lablottestid and sd.entereddate >= StartDate_FloatMeanSD.StartDateTime))
   and   LabLotTestID = @SelectedLabLotTestID
   ORDER BY sd.LabLotTestID

   OPEN SummaryData_Cursor

   FETCH NEXT FROM SummaryData_Cursor 
   INTO @LabLotTestID, 
        @L1Mean, @L1SD, @L1Points, @L2Mean, @L2SD, @L2Points, 
        @L3Mean, @L3SD, @L3Points, @L4Mean, @L4SD, @L4Points, 
        @L5Mean, @L5SD, @L5Points, @L6Mean, @L6SD, @L6Points, 
        @L7Mean, @L7SD, @L7Points, @L8Mean, @L8SD, @L8Points, 
        @L9Mean, @L9SD, @L9Points

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SELECT @L1CumMean = tms.Level1FloatMean, @L1CumSD = tms.Level1FloatSD, @L1CumPoints = tms.Level1FloatPoints, 
             @L2CumMean = tms.Level2FloatMean, @L2CumSD = tms.Level2FloatSD, @L2CumPoints = tms.Level2FloatPoints, 
             @L3CumMean = tms.Level3FloatMean, @L3CumSD = tms.Level3FloatSD, @L3CumPoints = tms.Level3FloatPoints, 
             @L4CumMean = tms.Level4FloatMean, @L4CumSD = tms.Level4FloatSD, @L4CumPoints = tms.Level4FloatPoints, 
             @L5CumMean = tms.Level5FloatMean, @L5CumSD = tms.Level5FloatSD, @L5CumPoints = tms.Level5FloatPoints, 
             @L6CumMean = tms.Level6FloatMean, @L6CumSD = tms.Level6FloatSD, @L6CumPoints = tms.Level6FloatPoints, 
             @L7CumMean = tms.Level7FloatMean, @L7CumSD = tms.Level7FloatSD, @L7CumPoints = tms.Level7FloatPoints, 
             @L8CumMean = tms.Level8FloatMean, @L8CumSD = tms.Level8FloatSD, @L8CumPoints = tms.Level8FloatPoints, 
             @L9CumMean = tms.Level9FloatMean, @L9CumSD = tms.Level9FloatSD, @L9CumPoints = tms.Level9FloatPoints      
      FROM #StartDate_FloatMeanSD tms
      WHERE tms.LabLotTestID = @LabLotTestID 

      --Process each set of points for each level by calling usp_CalculateMeanSD to combine to cumulative totals
      IF @L1Points > 0
         EXEC usp_CalculateMeanSD @L1Mean, @L1SD, @L1Points, @L1CumMean OUT, @L1CumSD OUT, @L1CumPoints OUT

      IF @L2Points > 0
         EXEC usp_CalculateMeanSD @L2Mean, @L2SD, @L2Points, @L2CumMean OUT, @L2CumSD OUT, @L2CumPoints OUT

      IF @L3Points > 0
         EXEC usp_CalculateMeanSD @L3Mean, @L3SD, @L3Points, @L3CumMean OUT, @L3CumSD OUT, @L3CumPoints OUT

      IF @L4Points > 0
         EXEC usp_CalculateMeanSD @L4Mean, @L4SD, @L4Points, @L4CumMean OUT, @L4CumSD OUT, @L4CumPoints OUT

      IF @L5Points > 0
         EXEC usp_CalculateMeanSD @L5Mean, @L5SD, @L5Points, @L5CumMean OUT, @L5CumSD OUT, @L5CumPoints OUT

      IF @L6Points > 0
         EXEC usp_CalculateMeanSD @L6Mean, @L6SD, @L6Points, @L6CumMean OUT, @L6CumSD OUT, @L6CumPoints OUT

      IF @L7Points > 0
         EXEC usp_CalculateMeanSD @L7Mean, @L7SD, @L7Points, @L7CumMean OUT, @L7CumSD OUT, @L7CumPoints OUT

      IF @L8Points > 0
         EXEC usp_CalculateMeanSD @L8Mean, @L8SD, @L8Points, @L8CumMean OUT, @L8CumSD OUT, @L8CumPoints OUT

      IF @L9Points > 0
         EXEC usp_CalculateMeanSD @L9Mean, @L9SD, @L9Points, @L9CumMean OUT, @L9CumSD OUT, @L9CumPoints OUT

      UPDATE #StartDate_FloatMeanSD
      SET Level1FloatMean = @L1CumMean, Level1FloatSD = @L1CumSD, Level1FloatPoints = @L1CumPoints, 
          Level2FloatMean = @L2CumMean, Level2FloatSD = @L2CumSD, Level2FloatPoints = @L2CumPoints, 
          Level3FloatMean = @L3CumMean, Level3FloatSD = @L3CumSD, Level3FloatPoints = @L3CumPoints, 
          Level4FloatMean = @L4CumMean, Level4FloatSD = @L4CumSD, Level4FloatPoints = @L4CumPoints, 
          Level5FloatMean = @L5CumMean, Level5FloatSD = @L5CumSD, Level5FloatPoints = @L5CumPoints, 
          Level6FloatMean = @L6CumMean, Level6FloatSD = @L6CumSD, Level6FloatPoints = @L6CumPoints, 
          Level7FloatMean = @L7CumMean, Level7FloatSD = @L7CumSD, Level7FloatPoints = @L7CumPoints, 
          Level8FloatMean = @L8CumMean, Level8FloatSD = @L8CumSD, Level8FloatPoints = @L8CumPoints, 
          Level9FloatMean = @L9CumMean, Level9FloatSD = @L9CumSD, Level9FloatPoints = @L9CumPoints
      WHERE LabLotTestID = @LabLotTestID


      FETCH NEXT FROM SummaryData_Cursor
      INTO @LabLotTestID, 
           @L1Mean, @L1SD, @L1Points, @L2Mean, @L2SD, @L2Points, 
           @L3Mean, @L3SD, @L3Points, @L4Mean, @L4SD, @L4Points, 
           @L5Mean, @L5SD, @L5Points, @L6Mean, @L6SD, @L6Points, 
           @L7Mean, @L7SD, @L7Points, @L8Mean, @L8SD, @L8Points, 
           @L9Mean, @L9SD, @L9Points

   END

   CLOSE SummaryData_Cursor
   DEALLOCATE SummaryData_Cursor

   
   --Update StartDate_FloatMeanSD table with calculated values
   UPDATE StartDate_FloatMeanSD
   SET StartDate_FloatMeanSD.Level1FloatMean = tms.Level1FloatMean, StartDate_FloatMeanSD.Level1FloatSD = tms.Level1FloatSD, StartDate_FloatMeanSD.Level1FloatPoints = tms.Level1FloatPoints, 
       StartDate_FloatMeanSD.Level2FloatMean = tms.Level2FloatMean, StartDate_FloatMeanSD.Level2FloatSD = tms.Level2FloatSD, StartDate_FloatMeanSD.Level2FloatPoints = tms.Level2FloatPoints, 
       StartDate_FloatMeanSD.Level3FloatMean = tms.Level3FloatMean, StartDate_FloatMeanSD.Level3FloatSD = tms.Level3FloatSD, StartDate_FloatMeanSD.Level3FloatPoints = tms.Level3FloatPoints, 
       StartDate_FloatMeanSD.Level4FloatMean = tms.Level4FloatMean, StartDate_FloatMeanSD.Level4FloatSD = tms.Level4FloatSD, StartDate_FloatMeanSD.Level4FloatPoints = tms.Level4FloatPoints, 
       StartDate_FloatMeanSD.Level5FloatMean = tms.Level5FloatMean, StartDate_FloatMeanSD.Level5FloatSD = tms.Level5FloatSD, StartDate_FloatMeanSD.Level5FloatPoints = tms.Level5FloatPoints, 
       StartDate_FloatMeanSD.Level6FloatMean = tms.Level6FloatMean, StartDate_FloatMeanSD.Level6FloatSD = tms.Level6FloatSD, StartDate_FloatMeanSD.Level6FloatPoints = tms.Level6FloatPoints, 
       StartDate_FloatMeanSD.Level7FloatMean = tms.Level7FloatMean, StartDate_FloatMeanSD.Level7FloatSD = tms.Level7FloatSD, StartDate_FloatMeanSD.Level7FloatPoints = tms.Level7FloatPoints, 
       StartDate_FloatMeanSD.Level8FloatMean = tms.Level8FloatMean, StartDate_FloatMeanSD.Level8FloatSD = tms.Level8FloatSD, StartDate_FloatMeanSD.Level8FloatPoints = tms.Level8FloatPoints, 
       StartDate_FloatMeanSD.Level9FloatMean = tms.Level9FloatMean, StartDate_FloatMeanSD.Level9FloatSD = tms.Level9FloatSD, StartDate_FloatMeanSD.Level9FloatPoints = tms.Level9FloatPoints
   FROM #StartDate_FloatMeanSD tms
   WHERE StartDate_FloatMeanSD.LabLotTestID = tms.LabLotTestID 


   --Clean existing StartDate_FloatMeanSD row if there is no row in temporary table for lablottestid/start date time and therefore
   --no balance available.
   UPDATE StartDate_FloatMeanSD
   SET StartDate_FloatMeanSD.Level1FloatMean = 0, StartDate_FloatMeanSD.Level1FloatSD = 0, StartDate_FloatMeanSD.Level1FloatPoints = 0, 
       StartDate_FloatMeanSD.Level2FloatMean = 0, StartDate_FloatMeanSD.Level2FloatSD = 0, StartDate_FloatMeanSD.Level2FloatPoints = 0, 
       StartDate_FloatMeanSD.Level3FloatMean = 0, StartDate_FloatMeanSD.Level3FloatSD = 0, StartDate_FloatMeanSD.Level3FloatPoints = 0, 
       StartDate_FloatMeanSD.Level4FloatMean = 0, StartDate_FloatMeanSD.Level4FloatSD = 0, StartDate_FloatMeanSD.Level4FloatPoints = 0, 
       StartDate_FloatMeanSD.Level5FloatMean = 0, StartDate_FloatMeanSD.Level5FloatSD = 0, StartDate_FloatMeanSD.Level5FloatPoints = 0, 
       StartDate_FloatMeanSD.Level6FloatMean = 0, StartDate_FloatMeanSD.Level6FloatSD = 0, StartDate_FloatMeanSD.Level6FloatPoints = 0, 
       StartDate_FloatMeanSD.Level7FloatMean = 0, StartDate_FloatMeanSD.Level7FloatSD = 0, StartDate_FloatMeanSD.Level7FloatPoints = 0, 
       StartDate_FloatMeanSD.Level8FloatMean = 0, StartDate_FloatMeanSD.Level8FloatSD = 0, StartDate_FloatMeanSD.Level8FloatPoints = 0, 
       StartDate_FloatMeanSD.Level9FloatMean = 0, StartDate_FloatMeanSD.Level9FloatSD = 0, StartDate_FloatMeanSD.Level9FloatPoints = 0
   WHERE LabLotTestID = @SelectedLabLotTestID
   and NOT EXISTS (SELECT 1 
                   FROM #StartDate_FloatMeanSD
                   WHERE StartDate_FloatMeanSD.LabLotTestID  = #StartDate_FloatMeanSD.LabLotTestID
                  )


GO


Update Misc 
Set Description = '2.4.3.002' Where Name = 'Version'
GO


