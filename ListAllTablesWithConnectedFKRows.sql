CREATE PROCEDURE dbo.Util_ListAllTablesWithConnectedFKRows
	@Schema varchar(100) = 'dbo',
	@Table varchar(100),
	@EntityId uniqueidentifier
AS
BEGIN
	/*
		-------------------
		--- Description ---
		-------------------

		https://github.com/rekestad/SQLServerToolkit
		
		Lists all tables that have rows with foreign keys to the given EntityId.
		
		Very useful when
			- you want a quick overview of how a row is connected (great for debugging!)
			- you need to see what's blocking the deletion of the row

		You're also served a ready-made SELECT script for all tables (ListRowsScript).

		Change the type of @Id to 'int' if you're using that as primary key instead of guids.
	*/
	SET NOCOUNT ON;
	
	-----------------------
	--- Declare/Prepare ---
	-----------------------

	DECLARE
		@SQLParams nvarchar(MAX) = '@Id uniqueidentifier',
		@Separator nvarchar(50) = ' UNION'+CHAR(13)+CHAR(10),
		@SQLScript nvarchar(MAX),
		@SQLInnerTemplate nvarchar(MAX) = '
SELECT 
	''#SCHEMA#.#TABLE#'' AS [DbTable], 
	''#COLUMN#'' AS [DbColumn], 
	COUNT(*) AS [NoOfRows], 
	CONCAT(''SELECT * FROM #SCHEMA#.#TABLE# X WHERE X.[#COLUMN#] = '''''', @Id, '''''''') AS [ListRowsScript] 
FROM 
	#SCHEMA#.#TABLE# X 
WHERE 
	X.[#COLUMN#] = @Id',
		@SQLTemplate nvarchar(MAX) = '
SELECT
	X.DbTable,
	X.DbColumn,
	X.NoOfRows,
	X.ListRowsScript
FROM
	(

#SELECTS#

	) X
WHERE 
	X.NoOfRows > 0 -- Show only tables that have connected rows
ORDER BY 
	X.DbTable,
	X.DbColumn;';

	CREATE TABLE #FKs
	(
		[PKTABLE_QUALIFIER] nvarchar(128),
		[PKTABLE_OWNER]     nvarchar(128),
		[PKTABLE_NAME]      nvarchar(128),
		[PKCOLUMN_NAME]     nvarchar(128),
		[FKTABLE_QUALIFIER] nvarchar(128),
		[FKTABLE_OWNER]     nvarchar(128),
		[FKTABLE_NAME]      nvarchar(128),
		[FKCOLUMN_NAME]     nvarchar(128),
		[KEY_SEQ]           smallint,
		[UPDATE_RULE]       smallint,
		[DELETE_RULE]       smallint,
		[FK_NAME]           nvarchar(128),
		[PK_NAME]           nvarchar(128),
		[DEFERRABILITY]     smallint
	);

	-----------------------------------
	--- Store FK list in temp table ---
	-----------------------------------

	INSERT INTO #FKs
	EXEC sys.sp_fkeys
		@pktable_name = @Table,
		@pktable_owner = @Schema;
 
	------------------------------------
	--- Construct dynamic SQL script ---
	------------------------------------

	;WITH Prep AS (
		SELECT
			STRING_AGG(X.SelectFromFKTable, @Separator) AS [Selects]
		FROM
			#FKs T
			CROSS APPLY (
				SELECT
					REPLACE(REPLACE(REPLACE(@SQLInnerTemplate, 
						'#SCHEMA#', T.FKTABLE_OWNER),
						'#TABLE#',	T.FKTABLE_NAME),
						'#COLUMN#',	T.FKCOLUMN_NAME
					) AS [SelectFromFKTable]
			) X
	)
	SELECT
		@SQLScript = REPLACE(@SQLTemplate,'#SELECTS#', P.Selects)
	FROM
		Prep P;

	--------------------------------------
	--- Execute SELECT and return list ---
	--------------------------------------

	EXEC sys.sp_executesql
		@stmt = @SQLScript,
		@params = @SQLParams,
		-- Parameters
		@Id = @EntityId;
END;