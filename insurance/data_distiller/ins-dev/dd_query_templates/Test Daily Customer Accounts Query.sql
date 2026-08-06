
INSERT INTO daily_customer_account_dataset
SELECT
  c._cognizanttechnologys.firstName     AS firstName,
  c._cognizanttechnologys.lastName      AS lastName,
  c._cognizanttechnologys.emailAddress  AS emailAddress,
  c._cognizanttechnologys.phoneNumber   AS phoneNumber,
  c._cognizanttechnologys.accountNumber AS accountNumber,
  c._cognizanttechnologys.dateOfBirth   AS dateOfBirth
FROM customer_profile_dataset c
WHERE CAST(c._cognizanttechnologys.accountNumber AS STRING) LIKE 'ACC%';
