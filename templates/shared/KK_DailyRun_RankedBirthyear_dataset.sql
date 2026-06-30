WITH RankedBirthdays AS (
    SELECT 
        SUBSTR(_cognizanttechnologys.profileDetails.DateOfBirth, 1, 4) as BirthYear,_cognizanttechnologys.profileDetails.DateOfBirth,*, 
        ROW_NUMBER() OVER (
            PARTITION BY SUBSTR(_cognizanttechnologys.profileDetails.DateOfBirth, 6, 4)
            ORDER BY _cognizanttechnologys.profileDetails.emailId DESC  -- e.g., created_at or ID to define "top"
        ) AS row_num
    FROM kkprofiledataset
)
SELECT *
FROM RankedBirthdays
WHERE row_num <= 1;