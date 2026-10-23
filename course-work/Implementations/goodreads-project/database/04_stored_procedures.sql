USE Goodreads;
GO

CREATE OR ALTER PROCEDURE dbo.sp_RegisterUser
    @Username     NVARCHAR(50),
    @Email        NVARCHAR(255),
    @Password     NVARCHAR(100),
    @FirstName    NVARCHAR(50),
    @LastName     NVARCHAR(50),
    @DateOfBirth  DATE         = NULL,
    @Country      NVARCHAR(60) = NULL,
    @NewUserId    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF LEN(@Password) < 6
        THROW 50001, 'Password must be at least 6 characters long.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Users WHERE Username = @Username)
        THROW 50002, 'Username is already taken.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Users WHERE Email = @Email)
        THROW 50003, 'Email is already registered.', 1;

    INSERT INTO dbo.Users (Username, Email, PasswordHash, FirstName, LastName, DateOfBirth, Country)
    VALUES (@Username, @Email,
            HASHBYTES('SHA2_256', @Password + @Username),
            @FirstName, @LastName, @DateOfBirth, @Country);

    SET @NewUserId = SCOPE_IDENTITY();
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AddBookToShelf
    @UserId       INT,
    @BookId       INT,
    @ShelfName    NVARCHAR(50),
    @DateFinished DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserId = @UserId)
        THROW 50004, 'User does not exist.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Books WHERE BookId = @BookId)
        THROW 50005, 'Book does not exist.', 1;

    DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
    DECLARE @ShelfId INT, @IsExclusive BIT, @PrevStarted DATE;

    BEGIN TRANSACTION;

    SELECT @ShelfId = ShelfId, @IsExclusive = IsExclusive
    FROM dbo.Shelves
    WHERE UserId = @UserId AND Name = @ShelfName;

    IF @ShelfId IS NULL
    BEGIN
        INSERT INTO dbo.Shelves (UserId, Name, IsExclusive) VALUES (@UserId, @ShelfName, 0);
        SET @ShelfId = SCOPE_IDENTITY();
        SET @IsExclusive = 0;
    END

    IF @IsExclusive = 1
    BEGIN
        SELECT @PrevStarted = sb.DateStarted
        FROM dbo.ShelfBooks sb
        JOIN dbo.Shelves s ON s.ShelfId = sb.ShelfId
        WHERE s.UserId = @UserId AND s.IsExclusive = 1 AND sb.BookId = @BookId;

        DELETE sb
        FROM dbo.ShelfBooks sb
        JOIN dbo.Shelves s ON s.ShelfId = sb.ShelfId
        WHERE s.UserId = @UserId AND s.IsExclusive = 1
          AND s.ShelfId <> @ShelfId AND sb.BookId = @BookId;
    END

    IF EXISTS (SELECT 1 FROM dbo.ShelfBooks WHERE ShelfId = @ShelfId AND BookId = @BookId)
    BEGIN
        UPDATE dbo.ShelfBooks
        SET DateFinished = CASE WHEN @ShelfName = 'read' THEN ISNULL(@DateFinished, @Today) ELSE DateFinished END
        WHERE ShelfId = @ShelfId AND BookId = @BookId;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.ShelfBooks (ShelfId, BookId, DateAdded, DateStarted, DateFinished)
        VALUES (@ShelfId, @BookId, @Today,
                CASE @ShelfName WHEN 'currently-reading' THEN @Today
                                WHEN 'read'              THEN @PrevStarted END,
                CASE WHEN @ShelfName = 'read' THEN ISNULL(@DateFinished, @Today) END);
    END

    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_AddReview
    @UserId     INT,
    @BookId     INT,
    @Rating     TINYINT,
    @ReviewText NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Rating NOT BETWEEN 1 AND 5
        THROW 50006, 'Rating must be between 1 and 5.', 1;

    BEGIN TRANSACTION;

    IF EXISTS (SELECT 1 FROM dbo.Reviews WHERE UserId = @UserId AND BookId = @BookId)
    BEGIN
        UPDATE dbo.Reviews
        SET Rating = @Rating,
            ReviewText = ISNULL(@ReviewText, ReviewText),
            UpdatedAt = SYSDATETIME()
        WHERE UserId = @UserId AND BookId = @BookId;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.Reviews (UserId, BookId, Rating, ReviewText)
        VALUES (@UserId, @BookId, @Rating, @ReviewText);
    END

    IF NOT EXISTS (SELECT 1
                   FROM dbo.ShelfBooks sb
                   JOIN dbo.Shelves s ON s.ShelfId = sb.ShelfId
                   WHERE s.UserId = @UserId AND s.Name = 'read' AND sb.BookId = @BookId)
    BEGIN
        EXEC dbo.sp_AddBookToShelf @UserId = @UserId, @BookId = @BookId, @ShelfName = 'read';
    END

    COMMIT TRANSACTION;

    SELECT BookId, Title, AverageRating, RatingsCount
    FROM dbo.Books WHERE BookId = @BookId;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_GetUserReadingStats
    @UserId INT,
    @Year   SMALLINT
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH ReadBooks AS (
        SELECT sb.BookId, sb.DateStarted, sb.DateFinished
        FROM dbo.ShelfBooks sb
        JOIN dbo.Shelves s ON s.ShelfId = sb.ShelfId
        WHERE s.UserId = @UserId AND s.Name = 'read'
          AND YEAR(sb.DateFinished) = @Year
    )
    SELECT u.Username,
           @Year                                             AS [Year],
           dbo.fn_GetUserBooksReadInYear(@UserId, @Year)     AS BooksRead,
           ISNULL(SUM(b.PageCount), 0)                       AS PagesRead,
           AVG(DATEDIFF(DAY, rb.DateStarted, rb.DateFinished)) AS AvgDaysPerBook,
           (SELECT CAST(AVG(CAST(r.Rating AS DECIMAL(5,2))) AS DECIMAL(3,2))
            FROM dbo.Reviews r
            WHERE r.UserId = @UserId AND r.BookId IN (SELECT BookId FROM ReadBooks)) AS AvgRatingGiven,
           rc.GoalBooks,
           dbo.fn_GetChallengeProgress(@UserId, @Year)       AS ChallengeProgressPct
    FROM dbo.Users u
    LEFT JOIN ReadBooks rb ON 1 = 1
    LEFT JOIN dbo.Books b  ON b.BookId = rb.BookId
    LEFT JOIN dbo.ReadingChallenges rc ON rc.UserId = u.UserId AND rc.[Year] = @Year
    WHERE u.UserId = @UserId
    GROUP BY u.Username, rc.GoalBooks;

    SELECT TOP (5) g.Name AS Genre, COUNT(*) AS BooksRead
    FROM dbo.ShelfBooks sb
    JOIN dbo.Shelves s     ON s.ShelfId = sb.ShelfId
    JOIN dbo.BookGenres bg ON bg.BookId = sb.BookId
    JOIN dbo.Genres g      ON g.GenreId = bg.GenreId
    WHERE s.UserId = @UserId AND s.Name = 'read' AND YEAR(sb.DateFinished) = @Year
    GROUP BY g.Name
    ORDER BY COUNT(*) DESC;
END;
GO

