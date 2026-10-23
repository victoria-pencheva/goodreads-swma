USE Goodreads;
GO

CREATE OR ALTER FUNCTION dbo.fn_GetBookAverageRating (@BookId INT)
RETURNS DECIMAL(3,2)
AS
BEGIN
    DECLARE @Avg DECIMAL(3,2);

    SELECT @Avg = CAST(AVG(CAST(Rating AS DECIMAL(5,2))) AS DECIMAL(3,2))
    FROM dbo.Reviews
    WHERE BookId = @BookId;

    RETURN ISNULL(@Avg, 0);
END;
GO

CREATE OR ALTER FUNCTION dbo.fn_GetUserBooksReadInYear (@UserId INT, @Year SMALLINT)
RETURNS INT
AS
BEGIN
    DECLARE @Cnt INT;

    SELECT @Cnt = COUNT(DISTINCT sb.BookId)
    FROM dbo.ShelfBooks sb
    JOIN dbo.Shelves s ON s.ShelfId = sb.ShelfId
    WHERE s.UserId = @UserId
      AND s.Name = 'read'
      AND sb.DateFinished >= DATEFROMPARTS(@Year, 1, 1)
      AND sb.DateFinished <  DATEFROMPARTS(@Year + 1, 1, 1);

    RETURN ISNULL(@Cnt, 0);
END;
GO

CREATE OR ALTER FUNCTION dbo.fn_GetTopBooksByGenre
(
    @GenreName  NVARCHAR(60),
    @Top        INT,
    @MinRatings INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT TOP (@Top)
           b.BookId,
           b.Title,
           STRING_AGG(a.FirstName + ' ' + a.LastName, ', ') AS Authors,
           b.AverageRating,
           b.RatingsCount
    FROM dbo.Books b
    JOIN dbo.BookGenres  bg ON bg.BookId  = b.BookId
    JOIN dbo.Genres      g  ON g.GenreId  = bg.GenreId
    JOIN dbo.BookAuthors ba ON ba.BookId  = b.BookId
    JOIN dbo.Authors     a  ON a.AuthorId = ba.AuthorId
    WHERE g.Name = @GenreName
      AND b.RatingsCount >= @MinRatings
    GROUP BY b.BookId, b.Title, b.AverageRating, b.RatingsCount
    ORDER BY b.AverageRating DESC, b.RatingsCount DESC
);
GO

CREATE OR ALTER FUNCTION dbo.fn_GetChallengeProgress (@UserId INT, @Year SMALLINT)
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @Pct DECIMAL(5,2);

    SELECT @Pct = CAST(CASE WHEN BooksRead >= GoalBooks THEN 100
                            ELSE BooksRead * 100.0 / GoalBooks END AS DECIMAL(5,2))
    FROM dbo.ReadingChallenges
    WHERE UserId = @UserId AND [Year] = @Year;

    RETURN @Pct;
END;
GO
