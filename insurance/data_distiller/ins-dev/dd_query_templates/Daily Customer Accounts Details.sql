SELECT
  _cognizanttechnologys.firstName as firstName,
  _cognizanttechnologys.lastName as lastName,
  _cognizanttechnologys.emailAddress as emailAddress,
  _cognizanttechnologys.phoneNumber as phoneNumber,
  _cognizanttechnologys.accountNumber as accountNumber,
  _cognizanttechnologys.dateOfBirth as dateOfBirth
FROM
  customer_profile_dataset
WHERE
  accountNumber LIKE 'ACC%';