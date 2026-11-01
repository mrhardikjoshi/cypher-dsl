# frozen_string_literal: true

# Translated from ExpressionsIT.java: COUNT subquery expressions.
module CypherDSL
  RSpec.describe 'ExpressionsIT' do
    it 'simple count subquery' do
      person = Cypher.node('Person').named(:person)
      cypher = Cypher.match(person)
                     .where(Cypher.count(person.relationship_to(Cypher.node('Dog'), 'HAS_DOG')).gt(Cypher.literal_of(1)))
                     .returning(person.property(:name).as(:name))
                     .build
                     .cypher
      expect(cypher).to eq('MATCH (person:`Person`) WHERE COUNT { (person)-[:`HAS_DOG`]->(:`Dog`) } > 1 RETURN person.name AS name')
    end

    it 'count subquery with where clause' do
      person = Cypher.node('Person').named(:person)
      dog = Cypher.node('Dog').named(:dog)
      cypher = Cypher.match(person)
                     .where(Cypher.count(person.relationship_to(dog, 'HAS_DOG'))
                                  .where(person.property(:name).eq(dog.property(:name)))
                                  .gt(Cypher.literal_of(1)))
                     .returning(person.property(:name).as(:name))
                     .build
                     .cypher
      expect(cypher).to eq(
        'MATCH (person:`Person`) WHERE COUNT { (person)-[:`HAS_DOG`]->(dog:`Dog`) WHERE person.name = dog.name } > 1 RETURN person.name AS name'
      )
    end

    it 'count subquery with union' do
      person = Cypher.node('Person').named(:person)
      dog = Cypher.node('Dog').named(:dog)
      cat = Cypher.node('Cat').named(:cat)
      inner = Cypher.union(
        Cypher.match(person.relationship_to(dog, 'HAS_DOG')).returning(dog.property(:name).as(:petName)).build,
        Cypher.match(person.relationship_to(cat, 'HAS_CAT')).returning(cat.property(:name).as(:petName)).build
      )
      cypher = Cypher.match(person)
                     .returning(person.property(:name).as(:name), Cypher.count(inner).as(:numPets))
                     .build
                     .cypher
      expect(cypher).to eq(
        'MATCH (person:`Person`) RETURN person.name AS name, COUNT { MATCH (person)-[:`HAS_DOG`]->(dog:`Dog`) RETURN dog.name AS petName UNION MATCH (person)-[:`HAS_CAT`]->(cat:`Cat`) RETURN cat.name AS petName } AS numPets'
      )
    end

    it 'count subquery with with' do
      person = Cypher.node('Person').named(:person)
      dog = Cypher.node('Dog').named(:d)
      dog_name = Cypher.literal_of('Ozzy').as(:dogName)
      cypher = Cypher.match(person)
                     .where(Cypher.subquery_with(dog_name)
                                  .count(person.relationship_to(dog, 'HAS_DOG'))
                                  .where(dog.property(:name).eq(dog_name))
                                  .eq(Cypher.literal_of(1)))
                     .returning(person.property(:name).as(:name))
                     .build
                     .cypher
      expect(cypher).to eq(
        "MATCH (person:`Person`) WHERE COUNT { WITH 'Ozzy' AS dogName MATCH (person)-[:`HAS_DOG`]->(d:`Dog`) WHERE d.name = dogName } = 1 RETURN person.name AS name"
      )
    end

    it 'count subquery in return' do
      person = Cypher.node('Person').named(:person)
      dog = Cypher.node('Dog')
      cypher = Cypher.match(person)
                     .returning(person.property(:name), Cypher.count(person.relationship_to(dog, 'HAS_DOG')).as(:howManyDogs))
                     .build
                     .cypher
      expect(cypher).to eq('MATCH (person:`Person`) RETURN person.name, COUNT { (person)-[:`HAS_DOG`]->(:`Dog`) } AS howManyDogs')
    end

    it 'count subquery in set' do
      person = Cypher.node('Person').named(:person)
      dog = Cypher.node('Dog')
      how_many_dogs = person.property(:howManyDogs)
      cypher = Cypher.match(person)
                     .where(person.property(:name).eq(Cypher.literal_of('Andy')))
                     .set(how_many_dogs.to(Cypher.count(person.relationship_to(dog, 'HAS_DOG'))))
                     .returning(how_many_dogs.as(:howManyDogs))
                     .build
                     .cypher
      expect(cypher).to eq(
        "MATCH (person:`Person`) WHERE person.name = 'Andy' SET person.howManyDogs = COUNT { (person)-[:`HAS_DOG`]->(:`Dog`) } RETURN person.howManyDogs AS howManyDogs"
      )
    end

    it 'count subquery in case' do
      person = Cypher.node('Person').named(:person)
      dog = Cypher.node('Dog')
      dog_count = Cypher.count(person.relationship_to(dog, 'HAS_DOG'))
      person_name = person.property(:name)
      cypher = Cypher.match(person)
                     .returning(Cypher.case_expression
                                      .when(dog_count.gt(Cypher.literal_of(1)))
                                      .then(Cypher.literal_of('Doglover ').concat(person_name))
                                      .else_default(person_name)
                                      .as(:result))
                     .build
                     .cypher
      expect(cypher).to eq(
        "MATCH (person:`Person`) RETURN CASE WHEN COUNT { (person)-[:`HAS_DOG`]->(:`Dog`) } > 1 THEN ('Doglover ' + person.name) ELSE person.name END AS result"
      )
    end

    it 'full statements as count sub query' do # GH-578
      p = Cypher.node('Person').named(:person)
      inner = Cypher.match(p.relationship_to(Cypher.node('Dog'), 'HAS_DOG')).returning(p.property(:name)).build
      outer = Cypher.match(p)
                    .where(Cypher.count(inner).eq(Cypher.literal_of(1)))
                    .returning(p.property(:name).as(:name))
                    .build
      expect(outer.cypher).to eq(
        'MATCH (person:`Person`) WHERE COUNT { MATCH (person)-[:`HAS_DOG`]->(:`Dog`) RETURN person.name } = 1 RETURN person.name AS name'
      )
    end

    it 'full statements as count sub query with imports' do # GH-578
      p = Cypher.node('Person').named(:person)
      d = Cypher.node('Dog').named(:d)
      dog_name = Cypher.name(:dogName)
      inner = Cypher.match(p.relationship_to(d, 'HAS_DOG'))
                    .where(d.property(:name).eq(dog_name))
                    .returning(p.property(:name))
                    .build
      outer = Cypher.match(p)
                    .where(Cypher.count(inner, Cypher.literal_of('Ozzy').as(dog_name)).eq(Cypher.literal_of(1)))
                    .returning(p.property(:name).as(:name))
                    .build
      expect(outer.cypher).to eq(
        "MATCH (person:`Person`) WHERE COUNT { WITH 'Ozzy' AS dogName MATCH (person)-[:`HAS_DOG`]->(d:`Dog`) WHERE d.name = dogName RETURN person.name } = 1 RETURN person.name AS name"
      )
    end
  end
end
