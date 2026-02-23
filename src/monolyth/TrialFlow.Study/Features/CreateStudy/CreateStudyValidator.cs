using FluentValidation;

namespace TrialFlow.Study.Features.CreateStudy;

public sealed class CreateStudyValidator : AbstractValidator<CreateStudyCommand>
{
    public CreateStudyValidator()
    {
        RuleFor(x => x.Title)
            .NotEmpty().WithMessage("Title is required.")
            .MaximumLength(500).WithMessage("Title must not exceed 500 characters.");
        RuleFor(x => x.Description)
            .MaximumLength(4000).WithMessage("Description must not exceed 4000 characters.");
    }
}
