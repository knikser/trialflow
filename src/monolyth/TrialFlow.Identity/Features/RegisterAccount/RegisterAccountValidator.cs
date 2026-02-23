using FluentValidation;

namespace TrialFlow.Identity.Features.RegisterAccount;

public sealed class RegisterAccountValidator : AbstractValidator<RegisterAccountCommand>
{
    public RegisterAccountValidator()
    {
        RuleFor(x => x.Email)
            .NotEmpty().WithMessage("Email is required.")
            .EmailAddress().WithMessage("Email must be a valid email address.")
            .MaximumLength(320).WithMessage("Email must not exceed 320 characters.");
        RuleFor(x => x.Password)
            .NotEmpty().WithMessage("Password is required.");
    }
}
