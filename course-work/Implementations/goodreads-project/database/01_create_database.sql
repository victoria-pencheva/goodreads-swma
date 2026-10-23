USE master;
GO

IF DB_ID('Goodreads') IS NOT NULL
BEGIN
    ALTER DATABASE Goodreads SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Goodreads;
END
GO

CREATE DATABASE Goodreads;
GO

USE Goodreads;
GO

CREATE TABLE dbo.Users (
    UserId        INT IDENTITY(1,1) CONSTRAINT PK_Users PRIMARY KEY,
    Username      NVARCHAR(50)  NOT NULL CONSTRAINT UQ_Users_Username UNIQUE,
    Email         NVARCHAR(255) NOT NULL CONSTRAINT UQ_Users_Email UNIQUE,
    PasswordHash  VARBINARY(64) NOT NULL,
    FirstName     NVARCHAR(50)  NOT NULL,
    LastName      NVARCHAR(50)  NOT NULL,
    DateOfBirth   DATE          NULL,
    Country       NVARCHAR(60)  NULL,
    Bio           NVARCHAR(500) NULL,
    JoinDate      DATETIME2(0)  NOT NULL CONSTRAINT DF_Users_JoinDate DEFAULT SYSDATETIME(),
    IsActive      BIT           NOT NULL CONSTRAINT DF_Users_IsActive DEFAULT 1,
    CONSTRAINT CK_Users_Email CHECK (Email LIKE '%_@_%._%')
);
GO

CREATE TABLE dbo.Authors (
    AuthorId      INT IDENTITY(1,1) CONSTRAINT PK_Authors PRIMARY KEY,
    FirstName     NVARCHAR(60)   NOT NULL,
    LastName      NVARCHAR(60)   NOT NULL,
    BirthDate     DATE           NULL,
    DeathDate     DATE           NULL,
    Nationality   NVARCHAR(60)   NULL,
    Biography     NVARCHAR(MAX)  NULL,
    Website       NVARCHAR(255)  NULL,
    CONSTRAINT CK_Authors_Dates CHECK (DeathDate IS NULL OR BirthDate IS NULL OR DeathDate > BirthDate)
);
GO

CREATE TABLE dbo.Publishers (
    PublisherId   INT IDENTITY(1,1) CONSTRAINT PK_Publishers PRIMARY KEY,
    Name          NVARCHAR(150) NOT NULL CONSTRAINT UQ_Publishers_Name UNIQUE,
    Country       NVARCHAR(60)  NULL,
    FoundedYear   SMALLINT      NULL CONSTRAINT CK_Publishers_Year CHECK (FoundedYear BETWEEN 1400 AND 2100),
    Website       NVARCHAR(255) NULL
);
GO

CREATE TABLE dbo.Genres (
    GenreId       INT IDENTITY(1,1) CONSTRAINT PK_Genres PRIMARY KEY,
    Name          NVARCHAR(60)  NOT NULL CONSTRAINT UQ_Genres_Name UNIQUE,
    Description   NVARCHAR(300) NULL
);
GO

CREATE TABLE dbo.Books (
    BookId          INT IDENTITY(1,1) CONSTRAINT PK_Books PRIMARY KEY,
    Title           NVARCHAR(255)  NOT NULL,
    ISBN            CHAR(13)       NULL CONSTRAINT UQ_Books_ISBN UNIQUE,
    PublisherId     INT            NULL CONSTRAINT FK_Books_Publishers REFERENCES dbo.Publishers(PublisherId),
    PublicationDate DATE           NULL,
    PageCount       INT            NULL CONSTRAINT CK_Books_Pages CHECK (PageCount > 0),
    Language        NVARCHAR(30)   NOT NULL CONSTRAINT DF_Books_Language DEFAULT 'English',
    Description     NVARCHAR(MAX)  NULL,
    CoverUrl        NVARCHAR(500)  NULL,
    AverageRating   DECIMAL(3,2)   NOT NULL CONSTRAINT DF_Books_AvgRating DEFAULT 0,
    RatingsCount    INT            NOT NULL CONSTRAINT DF_Books_RatingsCount DEFAULT 0
);
GO

CREATE TABLE dbo.BookAuthors (
    BookId     INT NOT NULL CONSTRAINT FK_BookAuthors_Books   REFERENCES dbo.Books(BookId)   ON DELETE CASCADE,
    AuthorId   INT NOT NULL CONSTRAINT FK_BookAuthors_Authors REFERENCES dbo.Authors(AuthorId) ON DELETE CASCADE,
    Role       NVARCHAR(30) NOT NULL CONSTRAINT DF_BookAuthors_Role DEFAULT 'Author',  -- Author, Co-author, Translator, Editor
    CONSTRAINT PK_BookAuthors PRIMARY KEY (BookId, AuthorId)
);
GO

CREATE TABLE dbo.BookGenres (
    BookId     INT NOT NULL CONSTRAINT FK_BookGenres_Books  REFERENCES dbo.Books(BookId)  ON DELETE CASCADE,
    GenreId    INT NOT NULL CONSTRAINT FK_BookGenres_Genres REFERENCES dbo.Genres(GenreId) ON DELETE CASCADE,
    CONSTRAINT PK_BookGenres PRIMARY KEY (BookId, GenreId)
);
GO

CREATE TABLE dbo.Shelves (
    ShelfId      INT IDENTITY(1,1) CONSTRAINT PK_Shelves PRIMARY KEY,
    UserId       INT          NOT NULL CONSTRAINT FK_Shelves_Users REFERENCES dbo.Users(UserId) ON DELETE CASCADE,
    Name         NVARCHAR(50) NOT NULL,
    IsExclusive  BIT          NOT NULL CONSTRAINT DF_Shelves_IsExclusive DEFAULT 0,
    CreatedAt    DATETIME2(0) NOT NULL CONSTRAINT DF_Shelves_CreatedAt DEFAULT SYSDATETIME(),
    CONSTRAINT UQ_Shelves_User_Name UNIQUE (UserId, Name)
);
GO

CREATE TABLE dbo.ShelfBooks (
    ShelfId      INT  NOT NULL CONSTRAINT FK_ShelfBooks_Shelves REFERENCES dbo.Shelves(ShelfId) ON DELETE CASCADE,
    BookId       INT  NOT NULL CONSTRAINT FK_ShelfBooks_Books   REFERENCES dbo.Books(BookId)    ON DELETE CASCADE,
    DateAdded    DATE NOT NULL CONSTRAINT DF_ShelfBooks_DateAdded DEFAULT CAST(SYSDATETIME() AS DATE),
    DateStarted  DATE NULL,
    DateFinished DATE NULL,
    CONSTRAINT PK_ShelfBooks PRIMARY KEY (ShelfId, BookId),
    CONSTRAINT CK_ShelfBooks_Dates CHECK (DateFinished IS NULL OR DateStarted IS NULL OR DateFinished >= DateStarted)
);
GO

CREATE TABLE dbo.Reviews (
    ReviewId    INT IDENTITY(1,1) CONSTRAINT PK_Reviews PRIMARY KEY,
    UserId      INT           NOT NULL CONSTRAINT FK_Reviews_Users REFERENCES dbo.Users(UserId) ON DELETE CASCADE,
    BookId      INT           NOT NULL CONSTRAINT FK_Reviews_Books REFERENCES dbo.Books(BookId) ON DELETE CASCADE,
    Rating      TINYINT       NOT NULL CONSTRAINT CK_Reviews_Rating CHECK (Rating BETWEEN 1 AND 5),
    ReviewText  NVARCHAR(MAX) NULL,
    CreatedAt   DATETIME2(0)  NOT NULL CONSTRAINT DF_Reviews_CreatedAt DEFAULT SYSDATETIME(),
    UpdatedAt   DATETIME2(0)  NULL,
    LikesCount  INT           NOT NULL CONSTRAINT DF_Reviews_Likes DEFAULT 0 CONSTRAINT CK_Reviews_Likes CHECK (LikesCount >= 0),
    CONSTRAINT UQ_Reviews_User_Book UNIQUE (UserId, BookId)
);
GO

CREATE TABLE dbo.Quotes (
    QuoteId        INT IDENTITY(1,1) CONSTRAINT PK_Quotes PRIMARY KEY,
    BookId         INT            NOT NULL CONSTRAINT FK_Quotes_Books REFERENCES dbo.Books(BookId) ON DELETE CASCADE,
    AuthorId       INT            NULL     CONSTRAINT FK_Quotes_Authors REFERENCES dbo.Authors(AuthorId),
    AddedByUserId  INT            NULL     CONSTRAINT FK_Quotes_Users REFERENCES dbo.Users(UserId),
    QuoteText      NVARCHAR(1000) NOT NULL,
    CreatedAt      DATETIME2(0)   NOT NULL CONSTRAINT DF_Quotes_CreatedAt DEFAULT SYSDATETIME(),
    LikesCount     INT            NOT NULL CONSTRAINT DF_Quotes_Likes DEFAULT 0
);
GO

CREATE TABLE dbo.ReadingChallenges (
    ChallengeId  INT IDENTITY(1,1) CONSTRAINT PK_ReadingChallenges PRIMARY KEY,
    UserId       INT          NOT NULL CONSTRAINT FK_Challenges_Users REFERENCES dbo.Users(UserId) ON DELETE CASCADE,
    [Year]       SMALLINT     NOT NULL CONSTRAINT CK_Challenges_Year CHECK ([Year] BETWEEN 2000 AND 2100),
    GoalBooks    INT          NOT NULL CONSTRAINT CK_Challenges_Goal CHECK (GoalBooks > 0),
    BooksRead    INT          NOT NULL CONSTRAINT DF_Challenges_BooksRead DEFAULT 0,
    CreatedAt    DATETIME2(0) NOT NULL CONSTRAINT DF_Challenges_CreatedAt DEFAULT SYSDATETIME(),
    CONSTRAINT UQ_Challenges_User_Year UNIQUE (UserId, [Year])
);
GO

CREATE TABLE dbo.Follows (
    FollowerId  INT          NOT NULL CONSTRAINT FK_Follows_Follower REFERENCES dbo.Users(UserId),
    FolloweeId  INT          NOT NULL CONSTRAINT FK_Follows_Followee REFERENCES dbo.Users(UserId),
    FollowedAt  DATETIME2(0) NOT NULL CONSTRAINT DF_Follows_FollowedAt DEFAULT SYSDATETIME(),
    CONSTRAINT PK_Follows PRIMARY KEY (FollowerId, FolloweeId),
    CONSTRAINT CK_Follows_NotSelf CHECK (FollowerId <> FolloweeId)
);
GO

CREATE INDEX IX_Books_PublisherId       ON dbo.Books(PublisherId);
CREATE INDEX IX_BookAuthors_AuthorId    ON dbo.BookAuthors(AuthorId);
CREATE INDEX IX_BookGenres_GenreId      ON dbo.BookGenres(GenreId);
CREATE INDEX IX_ShelfBooks_BookId       ON dbo.ShelfBooks(BookId);
CREATE INDEX IX_Reviews_BookId          ON dbo.Reviews(BookId) INCLUDE (Rating);
CREATE INDEX IX_Quotes_BookId           ON dbo.Quotes(BookId);
CREATE INDEX IX_Follows_FolloweeId      ON dbo.Follows(FolloweeId);
GO


