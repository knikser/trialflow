using FluentValidation;
using TrialFlow.Organization.Domain;

namespace TrialFlow.Organization.Features.CreateOrganization;

public sealed class CreateOrganizationValidator : AbstractValidator<CreateOrganizationCommand>
{
    public CreateOrganizationValidator()
    {
        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("Name is required.")
            .MaximumLength(300).WithMessage("Name must not exceed 300 characters.");
        RuleFor(x => x.Role)
            .IsInEnum().WithMessage("Role must be Sponsor or ResearchSite.");
    }
}
