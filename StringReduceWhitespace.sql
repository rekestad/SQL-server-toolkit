CREATE FUNCTION dbo.Util_String_ReduceWhitespace
(
    @String nvarchar(MAX)
)
RETURNS nvarchar(MAX)
AS
BEGIN
	/*
		-------------------
		--- Description ---
		-------------------
		
		https://github.com/rekestad/SQLServerToolkit/

		Does two things:
			1.	Replaces line breaks, tabs and multiple spaces in @String with one (1) space (' ')
			2.	Returns NULL if result from step 1 is empty or only whitespace, 
				otherwise returns result from step 1.

		Very useful for "washing" incoming data from an external API that has the nasty habit of 
		sending empty strings '' instead of NULL.

		#########################
		######## EXAMPLE ########
		#########################
		
		INPUT #1:

		PRINT dbo.Util_String_ReduceWhitespace('  This is a text with

		line breaks 
		
		and		tabs		and many      spaces.       ')

		OUTPUT #1:

		'This is a text with line breaks and tabs and many spaces.'

		INPUT #2:

		SELECT dbo.Util_String_ReduceWhitespace('      ')

		OUTPUT #2: 

		NULL
	*/
    RETURN NULLIF(
				TRIM(
					REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@String, 
						CHAR(13), ' '), 
						CHAR(10), ' '), 
						CHAR(9), ' '),
						' ',	'<¤¤>'),
						'¤><¤',	''),
						'<¤¤>',	' ')
				),
			'')
END;