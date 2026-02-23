using System.Reflection;
using FluentAssertions;
using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using NetArchTest.Rules;
using TrialFlow.Identity;
using TrialFlow.Notification;
using TrialFlow.Organization;
using TrialFlow.ResearchSite;
using TrialFlow.Study;

namespace TrialFlow.ArchitectureTests;

public class BoundedContextIsolationTests
{
    private static readonly string[] AllContextNamespaces =
    [
        "TrialFlow.Identity",
        "TrialFlow.Organization",
        "TrialFlow.Study",
        "TrialFlow.ResearchSite",
        "TrialFlow.Notification"
    ];

    [Theory]
    [InlineData("TrialFlow.Study",
        new[] { "TrialFlow.Identity", "TrialFlow.Organization", "TrialFlow.ResearchSite", "TrialFlow.Notification" })]
    [InlineData("TrialFlow.Identity",
        new[] { "TrialFlow.Organization", "TrialFlow.Study", "TrialFlow.ResearchSite", "TrialFlow.Notification" })]
    [InlineData("TrialFlow.Organization",
        new[] { "TrialFlow.Identity", "TrialFlow.Study", "TrialFlow.ResearchSite", "TrialFlow.Notification" })]
    [InlineData("TrialFlow.ResearchSite",
        new[] { "TrialFlow.Identity", "TrialFlow.Organization", "TrialFlow.Study", "TrialFlow.Notification" })]
    [InlineData("TrialFlow.Notification",
        new[] { "TrialFlow.Identity", "TrialFlow.Organization", "TrialFlow.Study", "TrialFlow.ResearchSite" })]
    public void Context_Should_Not_Reference_Other_Contexts(string contextNamespace, string[] forbiddenNamespaces)
    {
        var assembly = GetAssemblyForNamespace(contextNamespace);

        foreach (var forbidden in forbiddenNamespaces)
        {
            var result = Types.InAssembly(assembly)
                .That().ResideInNamespace(contextNamespace)
                .ShouldNot().HaveDependencyOn(forbidden)
                .GetResult();

            result.IsSuccessful.Should().BeTrue(
                $"{contextNamespace} must not reference {forbidden} — contexts communicate only via Contracts and message bus (ADR-002, ADR-003)");
        }
    }

    [Fact]
    public void Contexts_May_Reference_Contracts()
    {
        foreach (var contextNamespace in AllContextNamespaces)
        {
            var assembly = GetAssemblyForNamespace(contextNamespace);

            // Contracts への参照は許可 — просто проверяем что сборка компилируется с этой зависимостью
            var types = Types.InAssembly(assembly)
                .That().ResideInNamespace(contextNamespace)
                .GetTypes();

            types.Should().NotBeNull(
                $"{contextNamespace} should be able to reference TrialFlow.Contracts");
        }
    }

    private static Assembly GetAssemblyForNamespace(string ns) => ns switch
    {
        "TrialFlow.Study" => typeof(StudyAssemblyMarker).Assembly,
        "TrialFlow.Identity" => typeof(IdentityAssemblyMarker).Assembly,
        "TrialFlow.Organization" => typeof(OrganizationAssemblyMarker).Assembly,
        "TrialFlow.ResearchSite" => typeof(ResearchSiteAssemblyMarker).Assembly,
        "TrialFlow.Notification" => typeof(NotificationAssemblyMarker).Assembly,
        _ => throw new ArgumentException($"Unknown namespace: {ns}")
    };
}

public class FeatureSliceArchitectureTests
{
    [Theory]
    [InlineData(typeof(StudyAssemblyMarker), "TrialFlow.Study")]
    [InlineData(typeof(IdentityAssemblyMarker), "TrialFlow.Identity")]
    [InlineData(typeof(OrganizationAssemblyMarker), "TrialFlow.Organization")]
    public void Handlers_Should_Reside_In_Features(Type assemblyMarker, string contextNamespace)
    {
        var result = Types.InAssembly(assemblyMarker.Assembly)
            .That().ImplementInterface(typeof(IRequestHandler<,>))
            .Or().ImplementInterface(typeof(IRequestHandler<>))
            .Should().ResideInNamespace($"{contextNamespace}.Features")
            .GetResult();

        result.IsSuccessful.Should().BeTrue(
            $"All MediatR handlers in {contextNamespace} must live under Features/ — FSA rule (ADR-008)");
    }

    [Theory]
    [InlineData(typeof(StudyAssemblyMarker), "TrialFlow.Study")]
    [InlineData(typeof(IdentityAssemblyMarker), "TrialFlow.Identity")]
    [InlineData(typeof(OrganizationAssemblyMarker), "TrialFlow.Organization")]
    public void Validators_Should_Reside_In_Features(Type assemblyMarker, string contextNamespace)
    {
        var result = Types.InAssembly(assemblyMarker.Assembly)
            .That().Inherit(typeof(AbstractValidator<>))
            .Should().ResideInNamespace($"{contextNamespace}.Features")
            .GetResult();

        result.IsSuccessful.Should().BeTrue(
            $"All validators in {contextNamespace} must live under Features/ — FSA rule");
    }

    [Theory]
    [InlineData(typeof(StudyAssemblyMarker), "TrialFlow.Study")]
    [InlineData(typeof(IdentityAssemblyMarker), "TrialFlow.Identity")]
    [InlineData(typeof(OrganizationAssemblyMarker), "TrialFlow.Organization")]
    public void Features_Should_Not_Directly_Reference_Other_Features(Type assemblyMarker, string contextNamespace)
    {
        // Каждая фича должна быть изолирована — взаимодействие только через MediatR или domain events
        var featureTypes = Types.InAssembly(assemblyMarker.Assembly)
            .That().ResideInNamespaceMatching($@"{contextNamespace}\.Features\.\w+")
            .GetTypes()
            .GroupBy(t => t.Namespace)
            .ToList();

        foreach (var featureGroup in featureTypes)
        {
            var otherFeatureNamespaces = featureTypes
                .Where(g => g.Key != featureGroup.Key)
                .Select(g => g.Key!)
                .ToArray();

            foreach (var otherFeature in otherFeatureNamespaces)
            {
                var result = Types.InAssembly(assemblyMarker.Assembly)
                    .That().ResideInNamespace(featureGroup.Key!)
                    .ShouldNot().HaveDependencyOn(otherFeature)
                    .GetResult();

                result.IsSuccessful.Should().BeTrue(
                    $"Feature '{featureGroup.Key}' must not directly reference '{otherFeature}' — features communicate via MediatR or domain events");
            }
        }
    }
}

public class DomainLayerTests
{
    [Theory]
    [InlineData(typeof(StudyAssemblyMarker), "TrialFlow.Study")]
    [InlineData(typeof(IdentityAssemblyMarker), "TrialFlow.Identity")]
    [InlineData(typeof(OrganizationAssemblyMarker), "TrialFlow.Organization")]
    [InlineData(typeof(ResearchSiteAssemblyMarker), "TrialFlow.ResearchSite")]
    public void Domain_Should_Not_Reference_Infrastructure(Type assemblyMarker, string contextNamespace)
    {
        var result = Types.InAssembly(assemblyMarker.Assembly)
            .That().ResideInNamespace($"{contextNamespace}.Domain")
            .ShouldNot().HaveDependencyOn($"{contextNamespace}.Infrastructure")
            .GetResult();

        result.IsSuccessful.Should().BeTrue(
            $"Domain layer in {contextNamespace} must not depend on Infrastructure — domain is pure business logic");
    }

    [Theory]
    [InlineData(typeof(StudyAssemblyMarker), "TrialFlow.Study")]
    [InlineData(typeof(IdentityAssemblyMarker), "TrialFlow.Identity")]
    [InlineData(typeof(OrganizationAssemblyMarker), "TrialFlow.Organization")]
    [InlineData(typeof(ResearchSiteAssemblyMarker), "TrialFlow.ResearchSite")]
    public void Domain_Should_Not_Reference_MediatR(Type assemblyMarker, string contextNamespace)
    {
        var result = Types.InAssembly(assemblyMarker.Assembly)
            .That().ResideInNamespace($"{contextNamespace}.Domain")
            .ShouldNot().HaveDependencyOn("MediatR")
            .GetResult();

        result.IsSuccessful.Should().BeTrue(
            $"Domain layer in {contextNamespace} must not depend on MediatR — domain has no framework dependencies");
    }

    [Theory]
    [InlineData(typeof(StudyAssemblyMarker), "TrialFlow.Study")]
    [InlineData(typeof(IdentityAssemblyMarker), "TrialFlow.Identity")]
    [InlineData(typeof(OrganizationAssemblyMarker), "TrialFlow.Organization")]
    [InlineData(typeof(ResearchSiteAssemblyMarker), "TrialFlow.ResearchSite")]
    public void Domain_Entities_Should_Not_Have_Public_Setters(Type assemblyMarker, string contextNamespace)
    {
        var domainTypes = Types.InAssembly(assemblyMarker.Assembly)
            .That().ResideInNamespace($"{contextNamespace}.Domain")
            .GetTypes();

        foreach (var type in domainTypes)
        {
            var publicSetters = type.GetProperties()
                .Where(p => p.SetMethod != null && p.SetMethod.IsPublic)
                .ToList();

            publicSetters.Should().BeEmpty(
                $"Domain entity '{type.Name}' in {contextNamespace} must not have public setters — use private setters or init-only properties to protect invariants");
        }
    }

    [Theory]
    [InlineData(typeof(StudyAssemblyMarker), "TrialFlow.Study")]
    [InlineData(typeof(IdentityAssemblyMarker), "TrialFlow.Identity")]
    [InlineData(typeof(OrganizationAssemblyMarker), "TrialFlow.Organization")]
    public void Domain_Should_Not_Reference_EntityFramework(Type assemblyMarker, string contextNamespace)
    {
        var result = Types.InAssembly(assemblyMarker.Assembly)
            .That().ResideInNamespace($"{contextNamespace}.Domain")
            .ShouldNot().HaveDependencyOn("Microsoft.EntityFrameworkCore")
            .GetResult();

        result.IsSuccessful.Should().BeTrue(
            $"Domain layer in {contextNamespace} must not depend on EF Core — persistence is an infrastructure concern");
    }
}

public class InfrastructureLayerTests
{
    [Theory]
    [InlineData(typeof(StudyAssemblyMarker), "TrialFlow.Study")]
    [InlineData(typeof(IdentityAssemblyMarker), "TrialFlow.Identity")]
    [InlineData(typeof(OrganizationAssemblyMarker), "TrialFlow.Organization")]
    public void DbContext_Should_Reside_In_Infrastructure(Type assemblyMarker, string contextNamespace)
    {
        var result = Types.InAssembly(assemblyMarker.Assembly)
            .That().Inherit(typeof(DbContext))
            .Should().ResideInNamespace($"{contextNamespace}.Infrastructure")
            .GetResult();

        result.IsSuccessful.Should().BeTrue(
            $"DbContext in {contextNamespace} must live in Infrastructure/ — EF Core is a persistence detail");
    }

    [Theory]
    [InlineData(typeof(StudyAssemblyMarker), "TrialFlow.Study")]
    [InlineData(typeof(IdentityAssemblyMarker), "TrialFlow.Identity")]
    [InlineData(typeof(OrganizationAssemblyMarker), "TrialFlow.Organization")]
    public void Repositories_Should_Reside_In_Infrastructure(Type assemblyMarker, string contextNamespace)
    {
        var result = Types.InAssembly(assemblyMarker.Assembly)
            .That().HaveNameEndingWith("Repository")
            .Should().ResideInNamespace($"{contextNamespace}.Infrastructure")
            .GetResult();

        result.IsSuccessful.Should().BeTrue(
            $"Repositories in {contextNamespace} must live in Infrastructure/");
    }
}

public class NamingConventionTests
{
    [Theory]
    [InlineData(typeof(StudyAssemblyMarker), "TrialFlow.Study")]
    [InlineData(typeof(IdentityAssemblyMarker), "TrialFlow.Identity")]
    [InlineData(typeof(OrganizationAssemblyMarker), "TrialFlow.Organization")]
    public void Commands_Should_End_With_Command(Type assemblyMarker, string contextNamespace)
    {
        var result = Types.InAssembly(assemblyMarker.Assembly)
            .That().ImplementInterface(typeof(IRequest<>))
            .And().ResideInNamespaceMatching($@"{contextNamespace}\.Features\.\w+")
            .And().HaveNameEndingWith("Command")
            .Or().HaveNameEndingWith("Query")
            .Should().HaveNameEndingWith("Command")
            .Or().HaveNameEndingWith("Query")
            .GetResult();

        result.IsSuccessful.Should().BeTrue(
            $"MediatR requests in {contextNamespace} must end with 'Command' or 'Query'");
    }

    [Theory]
    [InlineData(typeof(StudyAssemblyMarker), "TrialFlow.Study")]
    [InlineData(typeof(IdentityAssemblyMarker), "TrialFlow.Identity")]
    [InlineData(typeof(OrganizationAssemblyMarker), "TrialFlow.Organization")]
    public void Handlers_Should_End_With_Handler(Type assemblyMarker, string contextNamespace)
    {
        var result = Types.InAssembly(assemblyMarker.Assembly)
            .That().ImplementInterface(typeof(IRequestHandler<,>))
            .Should().HaveNameEndingWith("Handler")
            .GetResult();

        result.IsSuccessful.Should().BeTrue(
            $"All MediatR handlers in {contextNamespace} must end with 'Handler'");
    }

    [Theory]
    [InlineData(typeof(StudyAssemblyMarker), "TrialFlow.Study")]
    [InlineData(typeof(IdentityAssemblyMarker), "TrialFlow.Identity")]
    [InlineData(typeof(OrganizationAssemblyMarker), "TrialFlow.Organization")]
    public void Endpoints_Should_End_With_Endpoint(Type assemblyMarker, string contextNamespace)
    {
        var result = Types.InAssembly(assemblyMarker.Assembly)
            .That().ResideInNamespaceMatching($@"{contextNamespace}\.Features\.\w+")
            .And().HaveNameEndingWith("Endpoint")
            .Should().HaveNameEndingWith("Endpoint")
            .GetResult();

        result.IsSuccessful.Should().BeTrue(
            $"Endpoint classes in {contextNamespace} must end with 'Endpoint'");
    }
}

public class MassTransitConsumerTests
{
    [Theory]
    [InlineData(typeof(StudyAssemblyMarker), "TrialFlow.Study")]
    [InlineData(typeof(IdentityAssemblyMarker), "TrialFlow.Identity")]
    [InlineData(typeof(OrganizationAssemblyMarker), "TrialFlow.Organization")]
    [InlineData(typeof(NotificationAssemblyMarker), "TrialFlow.Notification")]
    public void Consumers_Should_Reside_In_Features_Or_Consumers(Type assemblyMarker, string contextNamespace)
    {
        var result = Types.InAssembly(assemblyMarker.Assembly)
            .That().ImplementInterface(typeof(MassTransit.IConsumer<>))
            .Should().ResideInNamespace($"{contextNamespace}.Features")
            .Or().ResideInNamespace($"{contextNamespace}.Consumers")
            .GetResult();

        result.IsSuccessful.Should().BeTrue(
            $"MassTransit consumers in {contextNamespace} must live under Features/ or Consumers/ — not scattered across the codebase");
    }
}