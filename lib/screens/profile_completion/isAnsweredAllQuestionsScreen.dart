import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:lushh/appwrite/appwrite.dart';

const String biodataCollectionId = String.fromEnvironment(
  'BIODATA_COLLECTIONID',
);
const promptsCollectionId = String.fromEnvironment('PROMPTS_COLLECTIONID');
const String completionStatusCollectionId = String.fromEnvironment(
  'COMPLETION_STATUS_COLLECTIONID',
); 




class IsAnsweredAllQuestionsScreen extends StatefulWidget {
  const IsAnsweredAllQuestionsScreen({Key? key}) : super(key: key);

  @override
  State<IsAnsweredAllQuestionsScreen> createState() =>
      _IsAnsweredAllQuestionsScreenState();
}

class _IsAnsweredAllQuestionsScreenState
    extends State<IsAnsweredAllQuestionsScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _isSubmitting = false; // Add this line
  String? _gender; // 'male' or 'female'
  int _currentQuestionIndex = 0;
  List<int?> _answers = List.filled(
    5,
    null,
  ); // 5 questions, null if not answered

  // Color palette for different questions - Very light theme friendly colors
  final List<Color> _questionColors = [
    const Color(0xFF7B1FA2), // Dark Purple
    const Color(0xFFC2185B), // Dark Pink
    const Color(0xFF1976D2), // Dark Blue
    const Color(0xFF388E3C), // Dark Green
    const Color(0xFFF57C00), // Dark Orange
    const Color(0xFF512DA8), // Dark Deep Purple
    const Color(0xFF0097A7), // Dark Cyan
    const Color(0xFF6D4C41), // Dark Brown
    const Color(0xFF455A64), // Dark Blue Grey
    const Color(0xFFD32F2F), // Dark Red
  ];

  // Get the current question color
  Color get _currentQuestionColor =>
      _questionColors[_currentQuestionIndex % _questionColors.length];

  // Get very light variant of current question color
  Color get _currentQuestionLightColor =>
      const Color(0xFFFEFEFE); // Almost white

  // Questions and options for male and female
  static final List<Map<String, dynamic>> _maleQuestions = [
    {
      'question': 'The quality I admire most in a relationship is…',
      'options': [
        'Mutual respect',
        'Unconditional support',
        'Shared laughter',
        'Honesty and open communication',
        'Trust and loyalty',
        'A sense of adventure',
        'The ability to grow together',
        'Thoughtfulness',
        'Emotional intelligence',
        'Good communication',
      ],
    },
    {
      'question': 'I feel most connected when we are…',
      'options': [
        'Having a deep conversation over coffee',
        'Laughing at something completely silly',
        'Exploring a new place together',
        'Cooking a meal as a team',
        'Just being quiet and comfortable in each other\'s presence',
        'Talking about our dreams and goals',
        'Sharing our favorite music with each other',
        'Debating a movie\'s plot for hours',
        'Working on a project together',
        'Talking on a long drive',
      ],
    },
    {
      'question': 'I\'m looking for a partner who can challenge me to…',
      'options': [
        'Step outside my comfort zone',
        'Try new things',
        'Think more deeply about things',
        'Be more adventurous',
        'Improve my communication skills',
        'Be more emotionally intelligent',
        'Read more books',
        'Pursue my dreams',
        'Be a better version of myself',
      ],
    },
    {
      'question': 'The most romantic thing I can do for someone is…',
      'options': [
        'Making them a home-cooked meal',
        'Planning a surprise trip or adventure',
        'Making them a cup of tea',
        'Showing them I\'m listening by remembering the little things',
        'Supporting them when they\'re pursuing a dream',
        'Giving them a relaxing massage after a long day',
        'Bringing them flowers just because',
        'A romantic date',
        'Sending a thoughtful text just to say I\'m thinking of them',
        'Telling them how I feel',
      ],
    },
    {
      'question': 'The perfect gift I could receive is…',
      'options': [
        'A thoughtful, handwritten note',
        'An experience, not a thing',
        'Tickets to a sports game or a concert',
        'Something that shows you were really listening',
        'A surprise weekend trip',
        'A great book',
        'A great meal',
        'Something to help me with my hobby',
        'A day of no responsibilities',
        'Anything handmade',
      ],
    },
  ];

  static final List<Map<String, dynamic>> _femaleQuestions = [
    {
      'question': 'I know I’ve found a good match when…',
      'options': [
        'The conversation flows naturally',
        'He makes me laugh',
        'I feel a genuine connection',
        'He\'s a good listener',
        'We both forget to check our phones',
        'He\'s a good friend',
        'He challenges me to be a better person',
        'We have the same sense of humor',
        'He makes me feel safe',
        'We have a mutual respect',
      ],
    },
    {
      'question': 'A quality I admire most on a date is…',
      'options': [
        'Their ability to listen',
        'Their confidence',
        'Their thoughtfulness',
        'Their sense of humor',
        'Their manners',
        'Their ability to make me feel comfortable',
        'Their respect for my time',
        'Their ability to be present',
        'Their kindness',
        'Their honesty',
      ],
    },
    {
      'question': 'The best way to get to know me is…',
      'options': [
        'Over a good meal',
        'By asking me about my passions',
        'By having a deep conversation',
        'By just letting me be myself',
        'By seeing me with my friends',
        'By sharing a new experience with me',
        'Over a cup of tea',
        'By asking me about my dreams',
        'By just hanging out',
        'By trying a new cafe',
      ],
    },
    {
      'question': 'My communication style is best described as…',
      'options': [
        'Direct and honest',
        'I prefer to talk things out',
        'I\'m a good listener',
        'I\'m a good texter',
        'I\'m a great communicator',
        'I\'m a good listener, but I\'m also a great talker',
        'I\'m a good texter, but I prefer to talk on the phone',
        'I\'m a good communicator, but I\'m also a good listener',
        'I\'m a good communicator, but I\'m also a good texter',
        'I\'m a good communicator, but I also like to have fun',
      ],
    },
    {
      'question': 'My perfect first date would be…',
      'options': [
        'A long walk in a park',
        'Coffee at a local cafe',
        'Trying out a new restaurant or bar',
        'A quiet dinner where we can talk',
        'Getting an ice cream',
        'An adventurous road trip to a new city',
        'Bowling or mini golf',
        'A comedy show',
        'Going to a live music show',
        'A picnic',
      ],
    },
  ];
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  late final int _questionCount;
  late AnimationController _colorController;
  late Animation<Color?> _colorAnimation;
  Color? _previousColor;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
    _colorController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _previousColor = _currentQuestionColor;
    _colorAnimation = ColorTween(
      begin: _previousColor,
      end: _currentQuestionColor,
    ).animate(CurvedAnimation(
      parent: _colorController,
      curve: Curves.easeInOut,
    ));
    _colorController.value = 1.0;
    _questionCount = 5; // <-- Set this first!
    _updateProgressAnimation(); // <-- Now it's safe to use
    isAnsweredAllQuestionsScreenFetchGender();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  void _updateProgressAnimation() {
    final targetProgress = (_currentQuestionIndex + 1) / _questionCount;
    _progressAnimation = Tween<double>(
      begin: _progressAnimation.value,
      end: targetProgress,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
    _progressController.forward(from: 0.0);
  }

  void _animateColorTransition(Color newColor) {
    _colorAnimation = ColorTween(
      begin: _colorAnimation.value ?? _currentQuestionColor,
      end: newColor,
    ).animate(CurvedAnimation(
      parent: _colorController,
      curve: Curves.easeInOut,
    ));
    _colorController.forward(from: 0.0);
  }

  Future<void> isAnsweredAllQuestionsScreenFetchGender() async {
    try {
      final user = await account.get();
      final userId = user.$id;

      final bioDataDocument = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: biodataCollectionId,
        queries: [
          Query.equal('user', userId),
          Query.select(['gender']),
        ],
      );

      if (bioDataDocument.documents.isNotEmpty) {
        final gender = bioDataDocument.documents[0].data['gender']
            ?.toString()
            .toLowerCase();
        if (gender == 'male' || gender == 'female') {
          setState(() {
            _gender = gender;
            _isLoading = false;
          });
        } else {
          setState(() {
            _gender = null;
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _gender = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _gender = null;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get isAnsweredAllQuestionsScreenQuestions {
    if (_gender == 'male') return _maleQuestions;
    if (_gender == 'female') return _femaleQuestions;
    return [];
  }

  int get isAnsweredAllQuestionsScreenAnsweredCount =>
      _answers.where((a) => a != null).length;

  void isAnsweredAllQuestionsScreenSelectOption(int optionIndex) {
    setState(() {
      _answers[_currentQuestionIndex] = optionIndex;
    });
  }

  void isAnsweredAllQuestionsScreenGoToNext() {
    if (_currentQuestionIndex <
        isAnsweredAllQuestionsScreenQuestions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
      _updateProgressAnimation();
      _animateColorTransition(_currentQuestionColor);
    }
  }

  void isAnsweredAllQuestionsScreenGoToPrevious() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
      _updateProgressAnimation();
      _animateColorTransition(_currentQuestionColor);
    }
  }

  Future<void> isAnsweredAllQuestionsScreenSubmitAnswers() async {
    // Prevent double submission
    if (_isSubmitting) return;
    
    setState(() {
      _isSubmitting = true;
    });

    try {
      // Get current user
      final user = await account.get();
      final userId = user.$id;

      // Get the actual answer texts based on the selected indices
      String getAnswerText(int questionIndex) {
        if (_answers[questionIndex] == null) return '';
        final questions = isAnsweredAllQuestionsScreenQuestions;
        final options = questions[questionIndex]['options'] as List<String>;
        return options[_answers[questionIndex]!];
      }

      // Create the document data with actual answer texts
      final documentData = {
        'answer_1': getAnswerText(0),
        'answer_2': getAnswerText(1),
        'answer_3': getAnswerText(2),
        'answer_4': getAnswerText(3),
        'answer_5': getAnswerText(4),
        'answer_6': null,
        'answer_7': null,
        'user': userId,
      };

      // Create document in prompts collection
      await databases.createDocument(
        databaseId: databaseId,
        collectionId: promptsCollectionId,
        documentId: ID.unique(),
        data: documentData,
      );
           // Update completion status
        final userCompletionStatusDocument = await databases.listDocuments(
          databaseId: databaseId,
          collectionId: completionStatusCollectionId,
          queries: [
            Query.equal('user', userId),
            Query.select(['\$id']),
          ],
        );

            if (userCompletionStatusDocument.documents.isNotEmpty) {
          final documentId = userCompletionStatusDocument.documents[0].$id;
          await databases.updateDocument(
            databaseId: databaseId,
            collectionId: completionStatusCollectionId,
            documentId: documentId,
            data: {'isAnsweredQuestions': true, 'isAllCompleted': true},
          );
        }

      // Show success dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Your answers have been saved!',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
            ),
            backgroundColor: Colors.white,
            behavior: SnackBarBehavior.floating,
            elevation: 6,
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        // Redirect to main page after a short delay
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
          }
        });
      }
    } catch (e) {
      // Reset submitting state on error
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
      
      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to save answers: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _currentQuestionLightColor, // Dynamic light background
        body: Center(
          child: CircularProgressIndicator(
            color: _currentQuestionColor, // Dynamic color
          ),
        ),
      );
    }

    if (_gender == null) {
      return Scaffold(
        backgroundColor: _currentQuestionLightColor,
        body: const Center(
          child: Text(
            'Could not determine your gender.',
            style: TextStyle(color: Colors.black, fontFamily: 'SF Pro Display'),
          ),
        ),
      );
    }

    final question =
        isAnsweredAllQuestionsScreenQuestions[_currentQuestionIndex]['question']
            as String;
    final options =
        isAnsweredAllQuestionsScreenQuestions[_currentQuestionIndex]['options']
            as List<String>;
    final selectedOption = _answers[_currentQuestionIndex];

    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        final color = _colorAnimation.value ?? _currentQuestionColor;
        return Scaffold(
          backgroundColor: _currentQuestionLightColor, // Dynamic light background
          body: Container(
            color: _currentQuestionLightColor, // Ensure full coverage
            child: SafeArea(
              child: Column(
                children: [
                  // Scrollable content area
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 32),

                          // Main heading (now scrollable)
                          Text(
                            question,
                            style: TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                              color: color, // Dynamic color
                              letterSpacing: -0.5,
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Options list
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: options.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, idx) {
                              final isSelected = selectedOption == idx;
                              return GestureDetector(
                                onTap: () =>
                                    isAnsweredAllQuestionsScreenSelectOption(idx),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(
                                      0.15,
                                    ), // Lighter theme color
                                    borderRadius: BorderRadius.circular(
                                      25,
                                    ), // Fully rounded
                                    border: isSelected
                                        ? Border.all(
                                            color:
                                                color, // Dynamic color
                                            width: 2,
                                          )
                                        : null,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          options[idx],
                                          style: TextStyle(
                                            fontFamily: 'SF Pro Display',
                                            fontWeight: FontWeight.w500,
                                            fontSize: 16,
                                            color: Colors
                                                .black, // Black text on white boxes
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                          // Add some bottom padding for better scrolling experience
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                  // Fixed bottom section - Improved design
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 20.0,
                    ),
                    decoration: BoxDecoration(
                      color: _currentQuestionLightColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, -4),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Progress bar at top - More bubbly design
                        Container(
                          height: 8,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            children: [
                              // Background bubbles
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: List.generate(
                                  _questionCount,
                                  (index) => Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                              // Progress fill with bubbly effect
                              AnimatedBuilder(
                                animation: _progressAnimation,
                                builder: (context, child) {
                                  return FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: _progressAnimation.value,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: color.withOpacity(
                                              0.3,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: List.generate(
                                          _questionCount,
                                          (index) => Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: index <= _currentQuestionIndex
                                                  ? Colors.white.withOpacity(0.8)
                                                  : Colors.transparent,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Main bottom section
                        Row(
                          children: [
                            // Progress text with better styling
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Question ${_currentQuestionIndex + 1} of ${_questionCount}',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro Display',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black.withOpacity(0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${isAnsweredAllQuestionsScreenAnsweredCount} answered',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro Display',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 20),

                            // Previous button (only show if not first question)
                            if (_currentQuestionIndex > 0)
                              GestureDetector(
                                onTap: isAnsweredAllQuestionsScreenGoToPrevious,
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: color.withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.arrow_back,
                                    color: color,
                                    size: 20,
                                  ),
                                ),
                              ),

                            if (_currentQuestionIndex > 0)
                              const SizedBox(width: 12),

                            // Next/Submit button with improved design
                            GestureDetector(
                              onTap: selectedOption != null && !_isSubmitting
                                  ? (_currentQuestionIndex <
                                            _questionCount -
                                                1
                                        ? isAnsweredAllQuestionsScreenGoToNext
                                        : isAnsweredAllQuestionsScreenSubmitAnswers)
                                  : null,
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: selectedOption != null && !_isSubmitting
                                      ? color
                                      : color.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  boxShadow: selectedOption != null && !_isSubmitting
                                      ? [
                                          BoxShadow(
                                            color: color
                                                .withOpacity(0.4),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                            spreadRadius: 0,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: _isSubmitting && _currentQuestionIndex == _questionCount - 1
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Icon(
                                        _currentQuestionIndex <
                                                _questionCount -
                                                    1
                                            ? Icons.arrow_forward_rounded
                                            : Icons.check_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
