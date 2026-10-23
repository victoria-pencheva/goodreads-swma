USE Goodreads;
GO

CREATE OR ALTER TRIGGER dbo.trg_Reviews_UpdateBookRating
ON dbo.Reviews
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE b
    SET b.AverageRating = ISNULL(r.AvgRating, 0),
        b.RatingsCount  = ISNULL(r.Cnt, 0)
    FROM dbo.Books b
    JOIN (SELECT BookId FROM inserted
          UNION
          SELECT BookId FROM deleted) AS changed ON changed.BookId = b.BookId
    OUTER APPLY (
        SELECT CAST(AVG(CAST(rv.Rating AS DECIMAL(5,2))) AS DECIMAL(3,2)) AS AvgRating,
               COUNT(*) AS Cnt
        FROM dbo.Reviews rv
        WHERE rv.BookId = b.BookId
    ) AS r;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_ShelfBooks_UpdateChallenge
ON dbo.ShelfBooks
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH AffectedUsers AS (
        SELECT DISTINCT s.UserId
        FROM dbo.Shelves s
        WHERE s.ShelfId IN (SELECT ShelfId FROM inserted
                            UNION
                            SELECT ShelfId FROM deleted)
    )
    UPDATE rc
    SET rc.BooksRead = dbo.fn_GetUserBooksReadInYear(rc.UserId, rc.[Year])
    FROM dbo.ReadingChallenges rc
    JOIN AffectedUsers au ON au.UserId = rc.UserId;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Users_CreateDefaultShelves
ON dbo.Users
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.Shelves (UserId, Name, IsExclusive)
    SELECT i.UserId, d.Name, 1
    FROM inserted i
    CROSS JOIN (VALUES ('read'), ('currently-reading'), ('want-to-read')) AS d(Name);
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Shelves_ProtectDefault
ON dbo.Shelves
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
 
    IF EXISTS (SELECT 1
               FROM deleted d
               JOIN dbo.Users u ON u.UserId = d.UserId
               WHERE d.IsExclusive = 1)
        THROW 50010, 'Default shelves (read, currently-reading, want-to-read) cannot be deleted.', 1;
END;
GO

GO

