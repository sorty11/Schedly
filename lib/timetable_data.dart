class TimetableData {
  static final Map<String, Map<String, List<Map<String, String>>>> timetable = {
    'FY CSE A': {
      'Monday': [
        {
          'id': 'fyca_mon_001',
          'subject': 'Mathematics',
          'time': '9:00 AM - 10:00 AM',
          'room': 'A-101',
          'cancelled': 'true',
        },
        {
          'id': 'fyca_mon_002',
          'subject': 'Programming',
          'time': '10:00 AM - 11:00 AM',
          'room': 'Lab-3',
          'cancelled': 'false',
        },
      ],
      'Tuesday': [
        {
          'id': 'fyca_tue_001',
          'subject': 'BEEE',
          'time': '9:00 AM - 10:00 AM',
          'room': 'E-201',
          'cancelled': 'false',
        },
        {
          'id': 'fyca_tue_002',
          'subject': 'Physics',
          'time': '10:00 AM - 11:00 AM',
          'room': 'P-104',
          'cancelled': 'false',
        },
      ],
      'Wednesday': [
        {
          'id': 'fyca_wed_001',
          'subject': 'Flutter',
          'time': '9:00 AM - 10:00 AM',
          'room': 'Lab-5',
          'cancelled': 'true',
        },
        {
          'id': 'fyca_wed_002',
          'subject': 'DSA',
          'time': '10:00 AM - 11:00 AM',
          'room': 'A-203',
          'cancelled': 'false',
        },
      ],
      'Thursday': [],
      'Friday': [],
      'Saturday': [],
    },

    'FY CSE B': {
      'Monday': [
        {
          'id': 'fycb_mon_001',
          'subject': 'Physics',
          'time': '9:00 AM - 10:00 AM',
          'room': 'P-102',
          'cancelled': 'false',
        },
        {
          'id': 'fycb_mon_002',
          'subject': 'Chemistry',
          'time': '10:00 AM - 11:00 AM',
          'room': 'C-105',
          'cancelled': 'false',
        },
      ],
      'Tuesday': [
        {
          'id': 'fycb_tue_001',
          'subject': 'Programming',
          'time': '11:00 AM - 12:00 PM',
          'room': 'Lab-2',
          'cancelled': 'false',
        },
      ],
      'Wednesday': [],
      'Thursday': [],
      'Friday': [],
      'Saturday': [],
    },

    'SY CSE A': {
      'Monday': [
        {
          'id': 'syca_mon_001',
          'subject': 'OOP',
          'time': '9:00 AM - 10:00 AM',
          'room': 'CS-201',
          'cancelled': 'false',
        },
        {
          'id': 'syca_mon_002',
          'subject': 'DBMS',
          'time': '10:00 AM - 11:00 AM',
          'room': 'CS-202',
          'cancelled': 'false',
        },
      ],
      'Tuesday': [
        {
          'id': 'syca_tue_001',
          'subject': 'LADE',
          'time': '9:00 AM - 10:00 AM',
          'room': 'L-105',
          'cancelled': 'false',
        },
      ],
      'Wednesday': [],
      'Thursday': [],
      'Friday': [],
      'Saturday': [],
    },

    'SY CSE B': {
      'Monday': [
        {
          'id': 'sycb_mon_001',
          'subject': 'Java',
          'time': '9:00 AM - 10:00 AM',
          'room': 'CS-301',
          'cancelled': 'false',
        },
        {
          'id': 'sycb_mon_002',
          'subject': 'DBMS',
          'time': '10:00 AM - 11:00 AM',
          'room': 'CS-302',
          'cancelled': 'false',
        },
      ],
      'Tuesday': [],
      'Wednesday': [],
      'Thursday': [],
      'Friday': [],
      'Saturday': [],
    },

    'TY CSE A': {
      'Monday': [
        {
          'id': 'tyca_mon_001',
          'subject': 'Machine Learning',
          'time': '9:00 AM - 10:00 AM',
          'room': 'ML-101',
          'cancelled': 'false',
        },
      ],
      'Tuesday': [],
      'Wednesday': [],
      'Thursday': [],
      'Friday': [],
      'Saturday': [],
    },

    'TY CSE B': {
      'Monday': [
        {
          'id': 'tycb_mon_001',
          'subject': 'Cloud Computing',
          'time': '9:00 AM - 10:00 AM',
          'room': 'CC-201',
          'cancelled': 'false',
        },
      ],
      'Tuesday': [],
      'Wednesday': [],
      'Thursday': [],
      'Friday': [],
      'Saturday': [],
    },
  };
}