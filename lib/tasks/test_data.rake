require_dependency "decidim/faker/localized"

namespace :test_data do
  desc "test_data"
  task :load => :environment do
    lorem_ipsum_text = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus facilisis, tellus id iaculis ultricies, lectus metus egestas augue, a scelerisque tortor nibh in risus. Morbi vitae felis dui. In maximus, neque id molestie porttitor, orci mi viverra augue, sit amet sollicitudin arcu nisl quis nisi. In in arcu vel quam vestibulum porttitor. Vestibulum vel diam gravida, pharetra dui vitae, volutpat justo. Morbi aliquam accumsan est, quis tristique orci sollicitudin at. Praesent lobortis euismod mi ac blandit. Ut varius sit amet neque in sagittis. Sed a diam vitae sapien venenatis finibus. Sed a erat ut nunc elementum viverra et eu mauris. Vivamus ullamcorper porttitor metus porttitor convallis. Fusce sollicitudin elit consectetur, pulvinar ex quis, vestibulum tellus. Sed eget urna risus."

    o = Decidim::Organization.first
    o.update_attributes(name: "BCN Test")

    bcn_scopes = ["Ciutat", "Ciutat Vella", "Eixample", "Gràcia", "Horta-Guinardó", "Les Corts", "Nou Barris", "Sant Andreu", "Sant Martí", "Sants-Montjuïc", "Sarrià - Sant Gervasi"]
    o.scopes.each_with_index do |s, i|
      s.update_attributes(name: bcn_scopes[i])
    end
    bcn_scopes[3..-1].each do |s|
      o.scopes.create!(name: s)
    end

    pam_process = o.participatory_processes.first
    pam_process.update_attributes(
      title: { ca: "Pla d'Actuació Municipal", es: "Programa de Actuación Municipal" },
      slug: "pam",
      subtitle: { ca: "73 barris, una Barcelona. Cap a la ciutat dels drets i les oportunitats.", es: "73 barrios, una Barcelona. Hacia la ciudad de los derechos y las oportunidades." },
      hashtag: "#pam",
      promoted: true
    )

    feature = pam_process.features.where(manifest_name: 'accountability').first

    proposals_feature = pam_process.features.where(manifest_name: 'proposals')
    meetings_feature = pam_process.features.where(manifest_name: 'meetings')

    proposals = Decidim::Proposals::Proposal.where(feature: proposals_feature)
    meetings = Decidim::Meetings::Meeting.where(feature: meetings_feature)

    pam_process.categories.destroy_all
    Decidim::Accountability::Status.where(feature: feature).destroy_all
    Decidim::Accountability::Result.where(feature: feature).destroy_all

    Decidim::Accountability::Status.create!(feature: feature, key: "planned", name: { ca: "Planificat", es: "Planificado" })
    Decidim::Accountability::Status.create!(feature: feature, key: "ongoing", name: { ca: "En curs", es: "En curso" })
    Decidim::Accountability::Status.create!(feature: feature, key: "finished", name: { ca: "Acabat", es: "Terminado" })

    categories = {"Bon govern"=>["Participació ciutadana", "Acció comunitària", "Administració  intel·ligent i inclusiva", "Govern transparent  i rendició de comptes", "Eficiència i professionalitat"], "Transició ecològica"=>["Mobilitat sostenible", "Urbanisme per als barris", "Medi ambient i espai públic", "Verd urbà i biodiversitat ", "Energia i canvi climàtic"], "Bon viure"=>["Educació i coneixement ", "Esports", "Justícia social", "Autonomia personal ", "Equitat de gènere i diversitat sexual", "Sanitat i salut", "Cicles de vida ", "Habitatge", "Cultura", "Convivència i seguretat", "Migració, interculturalitat i discriminació zero", "Defensa i protecció dels Drets Humans"], "Economia plural"=>["Desenvolupament i economia de proximitat", "Turisme sostenible", "Ocupació de qualitat", "Economia cooperativa, social i solidària", "Un nou lideratge públic"], "Justícia global"=>["Ciutat d’acollida", "Justícia global"]}
    categories.each do |c, ss|
      cat = pam_process.categories.create(name: {ca: c, es: c}, description: {ca: c, es: c})
      ss.each do |s|
        pam_process.categories.create(parent: cat, name: {ca: s, es: s}, description: {ca: s, es: s})
      end
    end

    csv = File.read("#{Rails.root}/action_plans.csv")

    categories = []
    subcategories = {}

    CSV.parse(csv, headers: true).each do |row|
      row_scope = row[1]
      row_category = row[2]
      row_subcategory = row[3]
      row_title = row[4]
      row_desc = row[5]

      dscope = row_scope.presence ? o.scopes.find_by(name: row_scope) : nil

      category = pam_process.categories.select{|c| c.name["ca"] == row_category}.first
      subcategory = category.subcategories.select{|c| c.name["ca"] == row_subcategory}.first

      if category.blank? || subcategory.blank?
        puts "----"
        puts row
        puts dscope.inspect
        puts category.inspect
        puts subcategory.inspect

        next
      end

      result = Decidim::Accountability::Result.create!(
        feature: feature,
        scope: dscope,
        category: subcategory,
        title: { ca: row_title, es: row_title },
        description: { ca: row_desc, es: row_desc }
      )
      result.link_resources(proposals.sample(rand(10)), "included_proposals")

      rand(1..10).times do
        project_ref = SecureRandom.hex
        project = Decidim::Accountability::Result.create!(
          feature: feature,
          parent: result,
          start_date: Date.today,
          end_date: Date.today + 10,
          status: Decidim::Accountability::Status.where(feature: feature).sample,
          progress: rand(1..100),
          title: { ca: "Projecte #{project_ref}", es: "Proyecto #{project_ref}" },
          description: { ca: lorem_ipsum_text, es: lorem_ipsum_text }
        )
        project.link_resources(proposals.sample(rand(10)), "included_proposals")
      end
    end
  end
end
